class CreateUserRedemptionAudits < ActiveRecord::Migration[8.0]
  def change
    create_table :user_redemption_audits do |t|
      t.references :user_redemption, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.references :reward, null: false, foreign_key: true, index: true
      t.references :point_transaction, foreign_key: { to_table: :user_point_transactions }, index: true
      t.string :request_id, null: false
      t.string :change_source_origin, null: false
      t.string :change_reason, null: false
      t.jsonb :snapshot, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :user_redemption_audits, :request_id
    add_index :user_redemption_audits, [ :user_redemption_id, :created_at ]
    add_index :user_redemption_audits, [ :user_id, :created_at ]
    add_index :user_redemption_audits, [ :change_reason, :created_at ]
    add_check_constraint :user_redemption_audits, "char_length(request_id) > 0", name: "chk_user_redemption_audits_request_id_not_blank"
    add_check_constraint :user_redemption_audits, "char_length(change_source_origin) > 0", name: "chk_user_redemption_audits_change_source_origin_not_blank"
    add_check_constraint :user_redemption_audits, "char_length(change_reason) > 0", name: "chk_user_redemption_audits_change_reason_not_blank"
  end
end
