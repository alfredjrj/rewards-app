class AllowProcessingStatusForUserRedemptions < ActiveRecord::Migration[8.0]
  def up
    remove_check_constraint :user_redemptions, name: "chk_redemptions_status_valid"
    add_check_constraint :user_redemptions,
      "status IN ('processing', 'completed', 'failed', 'cancelled')",
      name: "chk_redemptions_status_valid"
  end

  def down
    remove_check_constraint :user_redemptions, name: "chk_redemptions_status_valid"
    add_check_constraint :user_redemptions,
      "status IN ('completed', 'failed', 'cancelled')",
      name: "chk_redemptions_status_valid"
  end
end
