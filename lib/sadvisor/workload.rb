require_relative './model'
require_relative './parser'

require 'graphviz'

module Sadvisor
  # A representation of a query workload over a given set of entities
  class Workload
    attr_reader :entities, :query_weights

    def initialize(&block)
      @query_weights = {}
      @entities = {}

      # Apply the DSL
      WorkloadDSL.new(self).instance_eval(&block) if block_given?
    end

    # Add a new {Entity} or {Statement} to the workload
    def <<(other)
      if other.is_a? Entity
        add_entity other.freeze
      elsif other.is_a? Statement
        add_query other.freeze
      else
        fail TypeError, 'can only add queries and entities to a workload'
      end
    end

    # Retrieve an entity by name
    # @return [Entity]
    def [](name)
      return @entities[name] if @entities.key? name
      fail EntityNotFound
    end

    # Add a new {Statement} to the workload or parse a string
    def add_query(query, weight = 1)
      query = Statement.new(query, self) if query.is_a? String

      @query_weights[query.freeze] = weight
    end

    # Strip the weights from the query dictionary and return a list of queries
    # @return [Array<Statement>]
    def queries
      @query_weights.keys
    end

    # Add an {Entity} to the workload
    def add_entity(entity)
      @entities[entity.name] = entity
    end

    # Find a field given an +Enumerable+ of identifiers
    # @return [Field]
    def find_field(field)
      if field.count > 2
        # Do a foreign key lookup
        field = field.dup
        key_field = @entities[field[0]].fields[field[1]]
        field[0..1] = key_field ? key_field.entity.name : field[1]
        find_field field
      else
        @entities[field[0]].fields[field[1]]
      end
    end

    # Check if all the fields used by queries in the workload exist
    # @return [Boolean]
    def fields_exist?
      @query_weights.keys.each do |query|
        # Projected fields and fields in the where clause exist
        fields = query.where.map { |condition| condition.field } + query.fields
        fields.each do |field|
          return false unless find_field field.value
        end
      end

      true
    end

    # Output a PNG representation of entities in the workload
    def output_png(filename, include_fields = false)
      graph = GraphViz.new :G, type: :digraph
      nodes = Hash[@entities.values.map do |entity|
        label = "#{entity.name}\n"
        if include_fields
          label += entity.fields.values.map do |field|
            type = field.class.name.sub(/^Sadvisor::(.*?)(Field)?$/, '\1')
            "#{field.name}: #{type}"
          end.join("\n")
        end

        [entity.name, graph.add_nodes(label)]
      end]

      entities.values.each do |entity|
        entity.foreign_keys.each do |key|
          graph.add_edges nodes[entity.name], nodes[key.entity.name]
        end
      end

      graph.output png: filename
    end
  end

  private

  # A helper class for DSL creation to avoid messing with {Workload}
  class WorkloadDSL
    def initialize(workload)
      @workload = workload
    end

    # rubocop:disable MethodName

    # Shortcut to add a new {Entity} to the workload
    def Entity(*args, &block)
      @workload.add_entity Entity.new(*args, &block)
    end

    # Shortcut to add a new {Statement} to the workload
    def Q(query, weight = 1.0)
      @workload.add_query query, weight
    end

    # rubocop:enable MethodName
  end

  # Raised when looking up an entity in the workload which does not exist
  class EntityNotFound < StandardError
  end
end
