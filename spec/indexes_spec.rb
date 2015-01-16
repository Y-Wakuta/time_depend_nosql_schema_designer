module NoSE
  describe Index do
    let(:workload) do
      Workload.new do
        Entity 'Corge' do
          Integer 'Quux'
        end

        (Entity 'Foo' do
          ID 'Id'
          Integer 'Bar'
          ForeignKey 'Corge', 'Corge'
        end) * 100
      end
    end
    let(:model) { workload.model }
    let(:equality_query) do
      Query.new 'SELECT Id FROM Foo WHERE Foo.Id = ?', model
    end
    let(:combo_query) do
      Query.new 'SELECT Id FROM Foo WHERE Foo.Id > ? AND Foo.Bar = ?',
                model
    end
    let(:order_query) do
      Query.new 'SELECT Id FROM Foo WHERE Foo.Id = ? ORDER BY Foo.Bar',
                model
    end

    before(:each) do
      workload.add_query equality_query
      workload.add_query combo_query
      workload.add_query order_query
    end

    it 'contains fields' do
      index = Index.new [model['Foo']['Id']], [], [], [model['Foo']]
      expect(index.contains_field? model['Foo']['Id']).to be true
    end

    it 'can store additional fields' do
      index = Index.new [model['Foo']['Id']], [], [model['Foo']['Bar']],
                        [model['Foo']]
      expect(index.contains_field? model['Foo']['Bar']).to be true
    end

    it 'can calculate its size' do
      index = Index.new([model['Foo']['Id']], [], [], [model['Foo']])
      expect(index.entry_size).to eq(model['Foo']['Id'].size)
      expect(index.size).to eq(model['Foo']['Id'].size *
                               model['Foo'].count)
    end

    context 'when materializing views' do
      it 'supports equality predicates' do
        index = equality_query.materialize_view
        expect(index.hash_fields).to eq([model['Foo']['Id']].to_set)
      end

      it 'support range queries' do
        index = combo_query.materialize_view
        expect(index.order_fields).to eq([model['Foo']['Id']])
      end

      it 'supports multiple predicates' do
        index = combo_query.materialize_view
        expect(index.hash_fields).to eq([model['Foo']['Bar']].to_set)
        expect(index.order_fields).to eq([model['Foo']['Id']])
      end

      it 'supports order by' do
        index = order_query.materialize_view
        expect(index.order_fields).to eq([model['Foo']['Bar']])
      end

      it 'keeps a static key' do
        index = combo_query.materialize_view
        expect(index.key).to eq 'i835299498'
      end
    end

    it 'can tell if it maps identities for a field' do
      index = Index.new([model['Foo']['Id']], [], [], [model['Foo']])
      expect(index.identity_for? model['Foo']).to be true
    end

    it 'can be created to map entity fields by id' do
      index = model['Foo'].simple_index
      expect(index.hash_fields).to eq([model['Foo']['Id']].to_set)
      expect(index.order_fields).to eq([])
      expect(index.extra).to eq([
        model['Foo']['Bar'],
        model['Foo']['Corge']
      ].to_set)
      expect(index.key).to eq 'Foo'
    end

    context 'when checking validity' do
      it 'cannot have empty hash fields' do
        expect do
          Index.new [], [], [model['Foo']['Id']], [model['Foo']]
        end.to raise_error
      end

      it 'must have fields at the start of the path' do
        expect do
          Index.new [model['Foo']['Id']], [], [],
                    [model['Corge'], model['Foo']]
        end.to raise_error InvalidIndexException
      end

      it 'must have fields at the end of the path' do
        expect do
          Index.new [model['Corge']['Quux']], [], [],
                    [model['Corge'], model['Foo']]
        end.to raise_error InvalidIndexException
      end
    end
  end
end
