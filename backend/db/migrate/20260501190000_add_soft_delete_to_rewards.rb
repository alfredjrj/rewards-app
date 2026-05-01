class AddSoftDeleteToRewards < ActiveRecord::Migration[8.0]
  FUNCTION_NAME = "prevent_rewards_hard_delete".freeze
  TRIGGER_NAME = "trg_prevent_rewards_hard_delete".freeze

  def up
    add_column :rewards, :deleted_at, :datetime
    add_index :rewards, :deleted_at

    execute <<~SQL
      CREATE OR REPLACE FUNCTION #{FUNCTION_NAME}()
      RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'rewards cannot be hard deleted; use soft delete (deleted_at) instead';
      END;
      $$ LANGUAGE plpgsql;
    SQL

    execute <<~SQL
      CREATE TRIGGER #{TRIGGER_NAME}
      BEFORE DELETE ON rewards
      FOR EACH ROW
      EXECUTE FUNCTION #{FUNCTION_NAME}();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS #{TRIGGER_NAME} ON rewards;
    SQL

    execute <<~SQL
      DROP FUNCTION IF EXISTS #{FUNCTION_NAME}();
    SQL

    remove_index :rewards, :deleted_at
    remove_column :rewards, :deleted_at
  end
end
