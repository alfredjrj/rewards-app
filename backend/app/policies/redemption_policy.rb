class RedemptionPolicy < ApplicationPolicy
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
    user.present?
  end
end
