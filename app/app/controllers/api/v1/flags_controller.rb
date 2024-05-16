class Api::V1::FlagsController < ApplicationController
  PERMITTED_PARAMS = [:flaggable_id, :flaggable_type]

  before_action :authenticate_user, only: [:create]

  def create
    flag = authenticated_user.flags.create_with(create_params)
      .create_or_find_by(create_params)

    # update will no-op in the usual case where flag didn't already exist
    if flag.update(create_params)
      head :created
    else
      render_error :unprocessable_entity, flag.errors.full_messages
    end
  end

  private

  def create_params
    params.require(:flag).permit(PERMITTED_PARAMS)
  end
end
