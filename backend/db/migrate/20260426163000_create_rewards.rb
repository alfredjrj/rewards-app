class CreateRewards < ActiveRecord::Migration[8.0]
  def up
    drop_table :rewards, if_exists: true

    create_table :rewards, comment: "Catalog of redeemable rewards" do |t|
      t.string :title, null: false, comment: "Display title shown to users"
      t.text :description, null: false, default: "", comment: "Detailed reward description"
      t.integer :points_cost, null: false, comment: "Points required to redeem this reward"
      t.string :reward_type, null: false, comment: "Reward category (e.g. vip_experience, discont)"
      t.boolean :is_available, null: false, default: true, comment: "Whether this reward can be redeemed"

      t.timestamps
    end

    # Supports title-based filtering/search in API endpoints.
    add_index :rewards, :title, name: "index_rewards_on_title_for_search"

    # Ensure data integrity at the database layer.
    add_check_constraint :rewards, "char_length(title) > 0", name: "chk_rewards_title_not_blank"
    add_check_constraint :rewards, "points_cost >= 0", name: "chk_rewards_points_cost_non_negative"
    add_check_constraint :rewards, "char_length(reward_type) > 0", name: "chk_rewards_reward_type_not_blank"
  end

  def down
    drop_table :rewards, if_exists: true
  end
end
