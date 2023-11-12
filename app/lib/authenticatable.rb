module Authenticatable
  HEADER_AUTHORIZATION = 'Authorization'.freeze
  SCOPE_CREATE_CONNECTIONS = 'create:connections'.freeze
  SCOPE_ALL = '*'.freeze

  def authenticated_user
    return @authenticated_user if @authenticated_user

    @authenticated_user = authenticate(auth_token, SCOPE_ALL)
  end

  def authenticate(jwt, scope)
    user_id = unauthenticated_user_id(jwt)
    user = User.find_by_id(user_id)
    return nil unless user;

    begin
      valid_jwt = JsonWebToken.decode(jwt, user.public_key)
    rescue JWT::DecodeError => error
      logger.error error
      return nil
    end

    return nil unless authorize(valid_jwt, scope)

    user
  end

  private

  def auth_token
    auth_header = request.headers[HEADER_AUTHORIZATION]
    auth_header&.start_with?('Bearer ') ? auth_header[7..] : nil
  end

  def authorize(jwt, scope)
    [scope, SCOPE_ALL].include? jwt[:scp]
  end

  def unauthenticated_user_id(jwt)
    begin
      JsonWebToken.unauthenticated_decode(jwt)[:sub]
    rescue JWT::DecodeError => error
      logger.error error
      nil
    end
  end
end
