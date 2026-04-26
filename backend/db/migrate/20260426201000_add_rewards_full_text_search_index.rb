class AddRewardsFullTextSearchIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "index_rewards_on_title_and_description_tsv".freeze

  def up
    execute <<~SQL
      CREATE INDEX CONCURRENTLY #{INDEX_NAME}
      ON rewards
      USING gin (
        (
          setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
          setweight(to_tsvector('english', coalesce(description, '')), 'B')
        )
      );
    SQL
  end

  def down
    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS #{INDEX_NAME};
    SQL
  end
end
