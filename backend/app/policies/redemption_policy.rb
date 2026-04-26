class RedemptionPolicy < ApplicationPolicy
  def create?
    user.present?
  end
end
