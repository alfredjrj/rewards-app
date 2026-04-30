# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_04_30_131000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "rewards", comment: "Catalog of redeemable rewards", force: :cascade do |t|
    t.string "title", null: false, comment: "Display title shown to users"
    t.text "description", default: "", null: false, comment: "Detailed reward description"
    t.integer "points_cost", null: false, comment: "Points required to redeem this reward"
    t.string "reward_type", null: false, comment: "Reward category (e.g. digital, voucher, physical)"
    t.boolean "is_available", default: true, null: false, comment: "Whether this reward can be redeemed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "((setweight(to_tsvector('english'::regconfig, (COALESCE(title, ''::character varying))::text), 'A'::\"char\") || setweight(to_tsvector('english'::regconfig, COALESCE(description, ''::text)), 'B'::\"char\")))", name: "index_rewards_on_title_and_description_tsv", using: :gin
    t.index ["title"], name: "index_rewards_on_title_for_search"
    t.check_constraint "char_length(reward_type::text) > 0", name: "chk_rewards_reward_type_not_blank"
    t.check_constraint "char_length(title::text) > 0", name: "chk_rewards_title_not_blank"
    t.check_constraint "points_cost >= 0", name: "chk_rewards_points_cost_non_negative"
  end

  create_table "user_point_transactions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "amount", null: false
    t.integer "running_balance", null: false
    t.string "kind", null: false
    t.string "source_type"
    t.bigint "source_id"
    t.string "idempotency_key", null: false
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "reason_code", null: false, comment: "Structured reason code for reporting and audits"
    t.index ["source_type", "source_id"], name: "index_user_point_transactions_on_source"
    t.index ["user_id", "created_at", "id"], name: "index_user_point_transactions_on_user_id_and_created_at_and_id"
    t.index ["user_id", "idempotency_key"], name: "index_user_point_transactions_on_user_id_and_idempotency_key", unique: true
    t.index ["user_id"], name: "index_user_point_transactions_on_user_id"
    t.check_constraint "amount <> 0", name: "chk_user_point_transactions_amount_non_zero"
    t.check_constraint "kind::text = ANY (ARRAY['earn'::character varying::text, 'redeem'::character varying::text, 'adjustment'::character varying::text, 'expiry'::character varying::text, 'reversal'::character varying::text])", name: "chk_user_point_transactions_kind_valid"
    t.check_constraint "reason_code::text = ANY (ARRAY['purchase'::character varying::text, 'reward_redemption'::character varying::text, 'manual_adjustment'::character varying::text, 'expiry'::character varying::text, 'reversal'::character varying::text, 'signup_bonus'::character varying::text, 'referral_bonus'::character varying::text, 'admin_correction'::character varying::text])", name: "chk_user_point_transactions_reason_code_valid"
    t.check_constraint "running_balance >= 0", name: "chk_user_point_transactions_running_balance_non_negative"
  end

  create_table "user_redemption_audits", force: :cascade do |t|
    t.bigint "user_redemption_id", null: false
    t.bigint "user_id", null: false
    t.bigint "reward_id", null: false
    t.bigint "point_transaction_id"
    t.string "request_id", null: false
    t.datetime "event_at", null: false
    t.string "change_source_origin", null: false
    t.string "change_reason", null: false
    t.jsonb "snapshot", default: {}, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["change_reason", "created_at"], name: "index_user_redemption_audits_on_change_reason_and_created_at"
    t.index ["point_transaction_id"], name: "index_user_redemption_audits_on_point_transaction_id"
    t.index ["request_id"], name: "index_user_redemption_audits_on_request_id"
    t.index ["reward_id"], name: "index_user_redemption_audits_on_reward_id"
    t.index ["user_id", "created_at"], name: "index_user_redemption_audits_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_user_redemption_audits_on_user_id"
    t.index ["user_redemption_id", "created_at"], name: "idx_on_user_redemption_id_created_at_14c1a4ca51"
    t.index ["user_redemption_id", "event_at", "id"], name: "idx_redemption_audits_redemption_event_at_id"
    t.index ["user_redemption_id"], name: "index_user_redemption_audits_on_user_redemption_id"
    t.check_constraint "char_length(change_reason::text) > 0", name: "chk_user_redemption_audits_change_reason_not_blank"
    t.check_constraint "char_length(change_source_origin::text) > 0", name: "chk_user_redemption_audits_change_source_origin_not_blank"
    t.check_constraint "char_length(request_id::text) > 0", name: "chk_user_redemption_audits_request_id_not_blank"
  end

  create_table "user_redemptions", comment: "Reward redemption records for users", force: :cascade do |t|
    t.bigint "user_id", null: false, comment: "User who redeemed the reward"
    t.bigint "reward_id", null: false, comment: "Reward that was redeemed"
    t.integer "points_cost_snapshot", null: false, comment: "Points cost at redemption time"
    t.string "status", default: "completed", null: false, comment: "Redemption status"
    t.string "idempotency_key", null: false, comment: "Idempotency key for duplicate request protection"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reward_id"], name: "index_user_redemptions_on_reward_id"
    t.index ["user_id", "created_at", "id"], name: "index_user_redemptions_on_user_id_and_created_at_and_id"
    t.index ["user_id", "idempotency_key"], name: "index_user_redemptions_on_user_id_and_idempotency_key", unique: true
    t.index ["user_id"], name: "index_user_redemptions_on_user_id"
    t.check_constraint "points_cost_snapshot >= 0", name: "chk_redemptions_points_cost_snapshot_non_negative"
    t.check_constraint "status::text = ANY (ARRAY['processing'::character varying::text, 'completed'::character varying::text, 'failed'::character varying::text, 'cancelled'::character varying::text])", name: "chk_redemptions_status_valid"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false, null: false
    t.index ["admin"], name: "index_users_on_admin"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "user_point_transactions", "users"
  add_foreign_key "user_redemption_audits", "rewards"
  add_foreign_key "user_redemption_audits", "user_point_transactions", column: "point_transaction_id"
  add_foreign_key "user_redemption_audits", "user_redemptions"
  add_foreign_key "user_redemption_audits", "users"
  add_foreign_key "user_redemptions", "rewards"
  add_foreign_key "user_redemptions", "users"
end
