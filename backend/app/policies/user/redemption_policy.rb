class User::RedemptionPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      scope.where(user_id: user.id)
    end
  end

  def index?
    user.present?
  end

  def create?
    return false unless user.present?
    return false unless record.user_id == user.id
    record.reward&.is_available? == true
  end
end
