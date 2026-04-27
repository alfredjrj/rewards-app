class Api::V1::User::ProfileSerializer
  def self.call(user:)
    {
      data: {
        id: user.id,
        email: user.email
      }
    }
  end
end
