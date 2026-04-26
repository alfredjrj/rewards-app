class RenameRedemptionsToUserRedemptions < ActiveRecord::Migration[8.0]
  def up
    return if table_exists?(:user_redemptions)
    return unless table_exists?(:redemptions)

    rename_table :redemptions, :user_redemptions

    rename_index_if_exists(
      :user_redemptions,
      "index_redemptions_on_reward_id",
      "index_user_redemptions_on_reward_id"
    )
    rename_index_if_exists(
      :user_redemptions,
      "index_redemptions_on_user_id",
      "index_user_redemptions_on_user_id"
    )
    rename_index_if_exists(
      :user_redemptions,
      "index_redemptions_on_user_id_and_created_at_and_id",
      "index_user_redemptions_on_user_id_and_created_at_and_id"
    )
    rename_index_if_exists(
      :user_redemptions,
      "index_redemptions_on_user_id_and_idempotency_key",
      "index_user_redemptions_on_user_id_and_idempotency_key"
    )
  end

  def down
    return if table_exists?(:redemptions)
    return unless table_exists?(:user_redemptions)

    rename_table :user_redemptions, :redemptions

    rename_index_if_exists(
      :redemptions,
      "index_user_redemptions_on_reward_id",
      "index_redemptions_on_reward_id"
    )
    rename_index_if_exists(
      :redemptions,
      "index_user_redemptions_on_user_id",
      "index_redemptions_on_user_id"
    )
    rename_index_if_exists(
      :redemptions,
      "index_user_redemptions_on_user_id_and_created_at_and_id",
      "index_redemptions_on_user_id_and_created_at_and_id"
    )
    rename_index_if_exists(
      :redemptions,
      "index_user_redemptions_on_user_id_and_idempotency_key",
      "index_redemptions_on_user_id_and_idempotency_key"
    )
  end

  private

  def rename_index_if_exists(table, from, to)
    rename_index(table, from, to) if index_name_exists?(table, from)
  end
end
