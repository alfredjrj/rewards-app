class RewardPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope

    def resolve
      return scope.none unless user.present?

      scope.where(is_available: true).order(:title)
    end
  end

  def index?
    user.present?
  end
end
