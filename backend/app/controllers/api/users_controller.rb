class Api::UsersController < ApplicationController
  def me
    render json: { id: current_user.id, email: current_user.email }
  end
end
