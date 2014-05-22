module Sadvisor
  describe Workload do
    let(:entity)      { Entity.new('Foo') << field }
    let(:field)       { IDField.new('Id') }
    let(:valid_query) { Parser.parse('SELECT Id FROM Foo') }

    before(:each) do
      subject.add_entity entity
    end

    it 'holds queries and entities' do
      expect(subject.entities).to have(1).item
      expect(subject.entities['Foo']).to be entity

      subject.add_query(valid_query)
      expect(subject.queries).to match_array [valid_query]
      expect(subject.valid?).to be_true
    end

    it 'rejects queries with unknown entities' do
      query = Parser.parse('SELECT Id FROM Bar')
      subject.add_query(query)
      expect(subject.valid?).to be_false
    end

    it 'rejects queries which select unknown fields' do
      query = Parser.parse('SELECT Bar FROM Foo')
      subject.add_query(query)
      expect(subject.valid?).to be_false
    end

    it 'rejects queries with multiple range predicates' do
      query = Parser.parse('SELECT Id FROM Foo ' \
                           'WHERE Foo.Id > 1 AND Foo.Id < 3')
      subject.add_query(query)
      expect(subject.valid?).to be_false
    end

    it 'rejects queries with unknown fields in where clauses' do
      query = Parser.parse('SELECT Id FROM Foo WHERE Foo.Bar = 1')
      subject.add_query(query)
      expect(subject.valid?).to be_false
    end

    it 'can find fields on entities from queries' do
      expect(subject.find_field %w(Foo Id)).to be field
    end

    it 'can find fields which traverse foreign keys' do
      other_entity = Entity.new 'Bar'
      other_field = IDField.new 'Quux'
      other_entity << other_field
      subject.add_entity other_entity

      entity << ForeignKey.new('Baz', other_entity)

      expect(subject.find_field %w(Foo Baz Quux)).to be other_field
    end

    context 'when checking for valid paths' do
      it 'accepts queries without a where clause' do
        query = Parser.parse('SELECT Id FROM Foo')
        expect(subject.send(:valid_paths?, query)).to be_true
      end

      it 'accepts queries with paths with a common prefix' do
        query = Parser.parse('SELECT Id FROM Foo WHERE ' \
                             'Foo.Bar.Baz = 1 AND Foo.Bar = 1')
        expect(subject.send(:valid_paths?, query)).to be_true
      end

      it 'rejects queries with paths without a common prefix' do
        query = Parser.parse('SELECT Id FROM Foo WHERE ' \
                             'Foo.Bar.Baz = 1 AND Foo.Quux = 1')
        expect(subject.send(:valid_paths?, query)).to be_false
      end
    end
  end
end
