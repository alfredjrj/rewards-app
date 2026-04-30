class PreventUserPointTransactionMutations < ActiveRecord::Migration[8.0]
  # Ledger rows are append-only: once written, point transactions must never be
  # updated or deleted. This DB trigger enforces that invariant even for raw SQL.
  FUNCTION_NAME = "prevent_user_point_transaction_mutations".freeze
  TRIGGER_NAME = "trg_prevent_user_point_transaction_mutations".freeze

  def up
    # Trigger function that always raises for UPDATE/DELETE attempts.
    execute <<~SQL
      CREATE OR REPLACE FUNCTION #{FUNCTION_NAME}()
      RETURNS trigger AS $$
      BEGIN
        RAISE EXCEPTION 'user_point_transactions is append-only: % is not allowed', TG_OP;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    # Attach the function to the ledger table so every row mutation is blocked.
    execute <<~SQL
      CREATE TRIGGER #{TRIGGER_NAME}
      BEFORE UPDATE OR DELETE ON user_point_transactions
      FOR EACH ROW
      EXECUTE FUNCTION #{FUNCTION_NAME}();
    SQL
  end

  def down
    # Roll back by removing trigger and function in dependency order.
    execute <<~SQL
      DROP TRIGGER IF EXISTS #{TRIGGER_NAME} ON user_point_transactions;
    SQL

    execute <<~SQL
      DROP FUNCTION IF EXISTS #{FUNCTION_NAME}();
    SQL
  end
end
