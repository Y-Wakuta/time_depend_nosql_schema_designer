# frozen_string_literal: true

NoSE::TimeDependWorkload.new do
  Model 'rubis'

  # Define queries and their relative weights, weights taken from below
  # http://rubis.ow2.org/results/SB-BMP/Bidding/JBoss-SB-BMP-Bi-1500/perf.html#run_stat
  # http://rubis.ow2.org/results/SB-BMP/Browsing/JBoss-SB-BMP-Br-1500/perf.html#run_stat
  DefaultMix :browsing
  TimeSteps 3

  Group 'UsersInfo', 1.0, :increase, browsing: 4.41,
        bidding: 2.48,
        write_medium: 2.48,
        write_heavy: 2.48 do
    Q 'SELECT users.* FROM users WHERE users.id = ? -- 8'
    F 'SELECT users.* FROM users WHERE users.id = ? -- 8',[0.5, 0.8, 0.1]
    Q 'SELECT users.* FROM users WHERE users.rating=? -- 12'
    F 'SELECT users.* FROM users WHERE users.rating=? -- 12',[0.5, 0.2, 0.2]
  end

  Group 'ItemsInfo', 1.0, :static, browsing: 8.82,
        bidding: 5.96,
        write_medium: 4.96,
        write_heavy: 4.96 do
    Q 'SELECT items.* FROM items WHERE items.id=? -- 13'
    Q 'SELECT items.* FROM items WHERE items.quantity=? -- 13'
  end
end
