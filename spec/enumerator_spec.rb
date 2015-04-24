module NoSE
  describe IndexEnumerator do
    include_context 'entities'

    subject(:enum) { IndexEnumerator.new workload }

    it 'produces a simple index for a filter' do
      query = Query.new 'SELECT Username FROM User WHERE User.City = ?',
                        workload.model
      indexes = enum.indexes_for_query query

      expect(indexes.to_a).to include \
        Index.new [user['City']], [user['UserId']], [user['Username']], [user]
    end

    it 'produces a simple index for a foreign key join' do
      query = Query.new 'SELECT Body FROM Tweet.User WHERE User.City = ?',
                        workload.model
      indexes = enum.indexes_for_query query

      expect(indexes).to include \
        Index.new [user['City']], [user['UserId'], tweet['TweetId']],
                  [tweet['Body']], [user, tweet]

      expect(indexes).not_to include \
        Index.new [user['City']], [tweet['TweetId']], [tweet['Body']],
                  [user, tweet]
    end

    it 'produces a simple index for a filter within a workload' do
      query = Query.new 'SELECT Username FROM User WHERE User.City = ?',
                        workload.model
      workload.add_statement query
      indexes = enum.indexes_for_workload

      expect(indexes.to_a).to include \
        Index.new [user['City']], [user['UserId']], [user['Username']], [user]
    end

    it 'does not produce empty indexes' do
      query = Query.new 'SELECT Body FROM Tweet.User WHERE User.City = ?',
                        workload.model
      workload.add_statement query
      indexes = enum.indexes_for_workload
      expect(indexes).to all(satisfy do |index|
        !index.order_fields.empty? || !index.extra.empty?
      end)
    end

    it 'includes no indexes for updates if nothing is updated' do
      # Use a fresh workload for this test
      model = workload.model
      workload = Workload.new model
      enum = IndexEnumerator.new workload
      update = Update.new 'UPDATE User SET Username = ? WHERE User.City = ?',
               model
      workload.add_statement update
      indexes = enum.indexes_for_workload

      expect(indexes).to be_empty
    end

    it 'includes indexes enumerated from queries generated from updates' do
      # Use a fresh workload for this test
      model = workload.model
      workload = Workload.new model
      enum = IndexEnumerator.new workload

      update = Update.new 'UPDATE User SET Username = ? WHERE User.City = ?',
                          model
      workload.add_statement update

      query = Query.new 'SELECT Body FROM Tweet.User WHERE User.Username = ?',
                        workload.model
      workload.add_statement query

      indexes = enum.indexes_for_workload

      expect(indexes.to_a).to include \
        Index.new [user['City']], [user['UserId']], [user['Username']], [user]
    end
  end
end
