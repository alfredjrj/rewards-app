class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :point_transactions,
           class_name: "User::PointTransaction",
           inverse_of: :user,
           dependent: :restrict_with_error
  has_many :redemptions,
           class_name: "User::Redemption",
           inverse_of: :user,
           dependent: :restrict_with_error

  def current_points_balance
    point_transactions.order(id: :desc).pick(:running_balance) || 0
  end
end
