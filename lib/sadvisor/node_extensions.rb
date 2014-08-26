require 'colorize'
require 'treetop'

# Elements of a query parse tree
module CQL
  # Abstract class used for nodes in the query parse tree
  class CQLNode < Treetop::Runtime::SyntaxNode
    include Memoist2

    # Two nodes in the parse tree are equal if they have the same value
    def ==(other)
      if self.respond_to?(:value) && other.respond_to?(:value)
        value == other.value
      else
        super
      end
    end

    def inspect
      return value.to_s if self.respond_to? :value
      super()
    end
  end

  # A parsed query
  class Statement < CQLNode
    # Produce a string with highlights using ANSI color codes
    # :nocov:
    def inspect
      return text_value unless $stdout.isatty

      out = 'SELECT '.green + \
            fields.map(&:value).map(&:last).map(&:blue).join(', '.green) + \
            ' FROM '.green + from.value.light_blue

      out += ' WHERE '.green if where.length > 0
      out += where.map do |condition|
        # require 'pry'
        # binding.pry
        field = condition.field.value
        where_out = field[0..-2].join('.').light_blue + '.' + field[-1].blue
        where_out += ' ' + condition.logical_operator.value.to_s.green + ' '
        where_out += condition.value.to_s.red

        where_out
      end.join(' AND '.green)

      out += ' ORDER BY '.green if order_by.length > 0
      out += order_by.map do |field|
        field[0..-2].join('.').light_blue + '.' + field[-1].blue
      end.join(', '.green)

      out += ' LIMIT '.green + limit.to_s.red if limit

      out
    end
    # :nocov:

    # All fields referenced anywhere in the query
    def all_fields
      all_fields = fields.map(&:value) + eq_fields.map do |condition|
        condition.field.value
      end
      all_fields << range_field.field.value unless range_field.nil?
      all_fields.to_set
    end

    # All fields projected by this query
    def fields
      fields = elements.find do |n|
        [CQL::Identifier, CQL::IdentifierList].include? n.class
      end
      fields.class == CQL::Identifier ? [fields] : fields.value
    end

    # Get the longest path through entities traversed in the query
    # @return [Array<String>]
    def longest_entity_path
      if where.length > 0
        fields = where.map { |condition| condition.field.value }
        fields += order_by
        fields.max_by(&:count)[0..-2]  # last item is a field name
      else
        [from.value]
      end
    end
    memoize :longest_entity_path

    # All conditions in the where clause of the query
    # @return [Array<CQL::Condition>]
    def where
      where = elements.find { |n| n.class == CQL::WhereClause }
      return [] if where.nil? || where.elements.length == 0

      conditions = []
      flatten_conditions = lambda do |node|
        if node.class == CQL::Condition
          conditions.push node
        else
          node.elements.each(&flatten_conditions)
        end
      end
      flatten_conditions.call where

      conditions
    end
    memoize :where

    # All fields with equality predicates in the where clause
    # @return [Array<Array<String>>]
    def eq_fields
      where.select { |condition| !condition.range? }
    end

    # The range predicate (if it exists) for this query
    # @return [Array<String>, nil]
    def range_field
      where.find { |condition| condition.range? }
    end

    # The integer limit for the query, or +nil+ if no limit is given
    # @return [Fixnum, nil]
    def limit
      limit = elements.find { |n| n.class == CQL::LimitClause }
      limit ? limit.value : nil
    end

    # The fields used in the order by clause for the query
    # @return [Array<Array<String>>]
    def order_by
      order_by = elements.find { |n| n.class == CQL::OrderByClause }
      order_by ? order_by.value : []
    end

    # The entity this query selects from
    # @return [String]
    def from
      elements.find { |n| [CQL::Entity].include? n.class }
    end
  end

  # A literal integer used in where clauses
  class IntegerLiteral < CQLNode
    # The integer value of the literal
    # @return [Fixnum]
    def value
      text_value.to_i
    end
  end

  # A literal float used in where clauses
  class FloatLiteral < CQLNode
    # The float value of the literal
    # @return [Float]
    def value
      text_value.to_f
    end
  end

  # A literal string used in where clauses
  class StringLiteral < CQLNode
    # The string value of the literal with quotes removed
    # @return [String]
    def value
      text_value[1..-2]
    end
  end

  # A simple alphabetic identifier used in queries
  class Identifier < CQLNode
    # The string value of the identifier
    def value
      if parent.class == Statement || parent.class == IdentifierList
        statement = parent
        statement = statement.parent while statement.class != Statement
        entity = statement.elements.find \
            { |child| child.class == Entity }.value
        [entity, text_value.to_s]
      else
        text_value.to_s
      end
    end
    memoize :value
  end

  # An entity name
  class Entity < Identifier
    # The name of the entity
    def value
      text_value.to_s
    end
  end

  # A field in a query
  class Field < CQLNode
    # A list of identifiers comprising the field name
    def value
      elements.map do |n|
        n.class == CQL::Field ? n.elements.map { |m| m.value } : n.value
      end.flatten
    end
  end

  # The limit clause of a query
  class LimitClause < CQLNode
    # The integer value of the limit
    # @return [Fixnum]
    def value
      elements[0].text_value.to_i
    end
  end

  # A list of fields used for ordering clauses
  class FieldList < CQLNode
    # A list of names of each field
    def value
      elements.map { |n| n.value }
    end
  end

  # The ordering clause of a query
  class OrderByClause < CQLNode
    # The list fields being ordered on
    def value
      fields = elements[0]
      fields.class == CQL::Field ? [fields.value] : fields.value
    end
  end

  # A list of fields a query projects
  class IdentifierList < CQLNode
    # An array of fields
    def value
      identifiers = []
      flatten_identifiers = lambda do |node|
        if node.class == CQL::Identifier
          identifiers.push node
        else
          node.elements.each(&flatten_identifiers)
        end
      end
      flatten_identifiers.call self

      identifiers
    end
    memoize :value
  end

  # A where clause in a query
  class WhereClause < CQLNode
  end

  # An expression in a where clause
  class Expression < CQLNode
  end

  # Represents a single predicate in a where clause
  class Condition < CQLNode
    # The field being compared
    def field
      elements[0]
    end

    # The value the field is being compared to
    def value
      elements[-1].class == CQL::Operator ? '?' : elements[-1].value
    end

    # The operator this condition applies to
    def logical_operator
      elements.find { |n| n.class == CQL::Operator }
    end

    # Check if this is a range predicate
    # @return [Boolean]
    def range?
      [:>, :>=, :<, :<=].include?(logical_operator.value)
    end
    memoize :range?
  end

  # An operator used for predicates in a where clause
  class Operator < CQLNode
    # A symbol representing the operator
    # @return[Symbol]
    def value
      text_value.to_sym
    end
  end
end
