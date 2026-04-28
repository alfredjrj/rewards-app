class User::Points::AvailableBalance
  def self.call(user:)
    new(user: user).call
  end

  def initialize(user:)
    @user = user
  end

  def call
    snapshot = ActiveRecord::Base.connection.select_one(balance_snapshot_sql)
    points_balance = snapshot.fetch("points_balance").to_i
    points_pending_redemption = snapshot.fetch("points_pending_redemption").to_i

    {
      points_balance: points_balance,
      points_pending_redemption: points_pending_redemption,
      points_available: [ points_balance - points_pending_redemption, 0 ].max
    }
  end

  private

  attr_reader :user

  def balance_snapshot_sql
    ActiveRecord::Base.send(
      :sanitize_sql_array,
      [
        <<~SQL.squish,
          SELECT
            COALESCE(
              (SELECT running_balance
               FROM user_point_transactions
               WHERE user_id = ?
               ORDER BY id DESC
               LIMIT 1), 0
            ) AS points_balance,
            COALESCE(
              (SELECT SUM(points_cost_snapshot)
               FROM user_redemptions
               WHERE user_id = ?
                 AND status = 'processing'), 0
            ) AS points_pending_redemption
        SQL
        user.id,
        user.id
      ]
    )
  end
end
