class CreateRedemptions < ActiveRecord::Migration[8.0]
  def change
    create_table :user_redemptions, comment: "Reward redemption records for users" do |t|
      t.references :user, null: false, foreign_key: true, comment: "User who redeemed the reward"
      t.references :reward, null: false, foreign_key: true, comment: "Reward that was redeemed"
      t.integer :points_cost_snapshot, null: false, comment: "Points cost at redemption time"
      t.string :status, null: false, default: "completed", comment: "Redemption status"
      t.string :idempotency_key, null: false, comment: "Idempotency key for duplicate request protection"

      t.timestamps
    end

    add_index :user_redemptions, [ :user_id, :idempotency_key ], unique: true
    add_index :user_redemptions, [ :user_id, :created_at, :id ]

    add_check_constraint :user_redemptions,
                         "points_cost_snapshot >= 0",
                         name: "chk_user_redemptions_points_cost_snapshot_non_negative"
    add_check_constraint :user_redemptions,
                         "status IN ('completed', 'failed', 'cancelled')",
                         name: "chk_user_redemptions_status_valid"
  end
end
