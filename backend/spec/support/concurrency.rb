RSpec.configure do |config|
  config.around(:each, :concurrency) do |example|
    original = self.class.use_transactional_tests
    self.class.use_transactional_tests = false
    example.run
  ensure
    self.class.use_transactional_tests = original

    ActiveRecord::Base.connection.disable_referential_integrity do
      tables = ActiveRecord::Base.connection.tables - %w[schema_migrations ar_internal_metadata]
      tables.each do |table|
        ActiveRecord::Base.connection.execute("DELETE FROM #{ActiveRecord::Base.connection.quote_table_name(table)}")
      end
    end
  end
end
