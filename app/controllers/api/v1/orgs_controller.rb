class Api::V1::OrgsController < ApplicationController
  PERMITTED_PARAMS = [
    :name,
    :potential_member_definition,
    :potential_member_estimate,
  ]

  before_action :authenticate_user, only: [:create]

  def create
    new_org = authenticated_user.build_org(create_params)
    if new_org.save
      render json: { id: new_org.id }, status: :created
    else
      render_error :unprocessable_entity, new_org.errors.full_messages
    end
  end

  private

  def create_params
    params.require(:org).permit(PERMITTED_PARAMS)
  end
end
