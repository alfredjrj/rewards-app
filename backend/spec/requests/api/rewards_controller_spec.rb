require "rails_helper"

RSpec.describe "Api::V1::RewardsController", type: :request do
  describe "GET /api/v1/rewards" do
    context "when not signed in" do
      it "returns unauthorized" do
        get "/api/v1/rewards"

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to eq("error" => "Not authenticated")
      end
    end

    context "when signed in" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "returns success" do
        create(:reward, title: "Coffee Voucher")
        create(:reward, title: "Movie Ticket")
        create(:reward, title: "Hidden Reward", is_available: false)

        get "/api/v1/rewards"

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].map { |r| r["title"] }).to eq([ "Coffee Voucher", "Movie Ticket" ])
        expect(body["meta"]).to include(
          "page" => 1,
          "per_page" => 6,
          "total_count" => 2,
          "total_pages" => 1
        )
      end

      it "searches across title and description using full-text search" do
        create(:reward, title: "Coffee Voucher", description: "Freshly brewed drink")
        create(:reward, title: "Movie Ticket", description: "Cinema popcorn combo")
        create(:reward, title: "Spa Session", description: "Relaxing coffee scrub")

        get "/api/v1/rewards", params: { filter: { query: "coffee" } }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].map { |r| r["title"] }).to eq([ "Coffee Voucher", "Spa Session" ])
      end

      it "supports prefix matching for short queries" do
        create(:reward, title: "Chef Special", description: "Limited-time menu item")
        create(:reward, title: "Coffee Voucher", description: "Freshly brewed drink")

        get "/api/v1/rewards", params: { filter: { query: "ch" } }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].map { |r| r["title"] }).to include("Chef Special")
      end

      it "supports page-based pagination" do
        create(:reward, title: "Alpha")
        create(:reward, title: "Bravo")
        create(:reward, title: "Charlie")
        create(:reward, title: "Delta")

        get "/api/v1/rewards", params: { page: 2, per_page: 2 }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].map { |r| r["title"] }).to eq([ "Charlie", "Delta" ])
        expect(body["meta"]).to include(
          "page" => 2,
          "per_page" => 2,
          "total_count" => 4,
          "total_pages" => 2
        )
      end

      it "filters by multiple reward types" do
        create(:reward, title: "Coffee Voucher", reward_type: "free_item")
        create(:reward, title: "Movie Ticket", reward_type: "vip_experience")
        create(:reward, title: "Secret Burger", reward_type: "secret_menu")

        get "/api/v1/rewards", params: { filter: { reward_types: [ "free_item", "vip_experience" ] } }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].map { |r| r["title"] }).to eq([ "Coffee Voucher", "Movie Ticket" ])
      end

      it "filters by affordability using filter[points][lte]" do
        create(:reward, title: "Coffee Voucher", points_cost: 100)
        create(:reward, title: "Movie Ticket", points_cost: 500)

        get "/api/v1/rewards", params: { filter: { points: { lte: 150 } } }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].map { |r| r["title"] }).to eq([ "Coffee Voucher" ])
      end

      it "filters by minimum points using filter[points][gte]" do
        create(:reward, title: "Coffee Voucher", points_cost: 100)
        create(:reward, title: "Movie Ticket", points_cost: 500)

        get "/api/v1/rewards", params: { filter: { points: { gte: 200 } } }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].map { |r| r["title"] }).to eq([ "Movie Ticket" ])
      end

      it "filters by points range using gte and lte" do
        create(:reward, title: "Coffee Voucher", points_cost: 100)
        create(:reward, title: "Movie Ticket", points_cost: 250)
        create(:reward, title: "Spa Session", points_cost: 500)

        get "/api/v1/rewards", params: { filter: { points: { gte: 150, lte: 300 } } }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].map { |r| r["title"] }).to eq([ "Movie Ticket" ])
      end

      it "sorts by whitelisted fields using sort param" do
        create(:reward, title: "A Item", points_cost: 200)
        create(:reward, title: "B Item", points_cost: 100)

        get "/api/v1/rewards", params: { sort: "-points_cost" }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].map { |r| r["title"] }).to eq([ "A Item", "B Item" ])
      end
    end
  end
end
