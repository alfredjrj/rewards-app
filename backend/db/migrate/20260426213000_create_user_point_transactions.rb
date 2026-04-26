class CreateUserPointTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :user_point_transactions, comment: "Immutable ledger of user point movements" do |t|
      t.references :user, null: false, foreign_key: true, comment: "Owner of this ledger entry"
      t.integer :amount, null: false, comment: "Signed delta: +earn, -redeem/expiry/reversal"
      t.integer :running_balance, null: false, comment: "User point balance immediately after this entry"
      t.string :kind, null: false, comment: "Transaction type: earn, redeem, adjustment, expiry, reversal"
      t.references :source, polymorphic: true, comment: "Optional source record for traceability"
      t.string :idempotency_key, null: false, comment: "Client/server idempotency token"
      t.string :reason, comment: "Human-readable reason for manual adjustments or audits"

      t.timestamps
    end

    add_index :user_point_transactions, [ :user_id, :idempotency_key ], unique: true
    add_index :user_point_transactions, [ :user_id, :created_at, :id ]

    add_check_constraint :user_point_transactions,
                         "amount <> 0",
                         name: "chk_user_point_transactions_amount_non_zero"
    add_check_constraint :user_point_transactions,
                         "running_balance >= 0",
                         name: "chk_user_point_transactions_running_balance_non_negative"
    add_check_constraint :user_point_transactions,
                         "kind IN ('earn', 'redeem', 'adjustment', 'expiry', 'reversal')",
                         name: "chk_user_point_transactions_kind_valid"
  end
end
