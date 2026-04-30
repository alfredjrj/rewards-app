class AddFulfillmentProviderToRewards < ActiveRecord::Migration[8.0]
  def change
    add_column :rewards, :fulfillment_provider, :string, null: false, default: "internal"
  end
end
