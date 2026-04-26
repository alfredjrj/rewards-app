class AddReasonCodeToUserPointTransactions < ActiveRecord::Migration[8.0]
  REASON_CODES = %w[
    purchase
    reward_redemption
    manual_adjustment
    expiry
    reversal
    signup_bonus
    referral_bonus
    admin_correction
  ].freeze

  def change
    add_column :user_point_transactions,
               :reason_code,
               :string,
               null: false,
               default: "admin_correction",
               comment: "Structured reason code for reporting and audits"

    add_check_constraint :user_point_transactions,
                         "reason_code IN ('#{REASON_CODES.join("', '")}')",
                         name: "chk_user_point_transactions_reason_code_valid"

    change_column_default :user_point_transactions, :reason_code, from: "admin_correction", to: nil
  end
end
