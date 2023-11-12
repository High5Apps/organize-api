require "test_helper"

class Api::V1::PostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    p = posts(:one)
    @params = { post: p.attributes.as_json.with_indifferent_access }

    @user = users(:one)
    setup_test_key(@user)
    @authorized_headers = authorized_headers(@user, Authenticatable::SCOPE_ALL)
  end

  test 'should create with valid params' do
    assert_difference 'Post.count', 1 do
      post api_v1_posts_url, headers: @authorized_headers, params: @params
      assert_response :created
    end

    json_response = JSON.parse(response.body, symbolize_names: true)
    assert_not_nil json_response.dig(:id)
    assert Time.iso8601(json_response.dig(:created_at))
  end

  test 'should not create with invalid authorization' do
    assert_no_difference 'Post.count' do
      post api_v1_posts_url, headers: { Authorization: 'bad'}, params: @params
      assert_response :unauthorized
    end
  end

  test 'should not create with invalid params' do
    assert_no_difference 'Post.count' do
      post api_v1_posts_url, headers: @authorized_headers, params: {
        post: @params[:post].except(:category)
      }
      assert_response :unprocessable_entity
    end
  end

  test 'should not create if user is not in an org' do
    @user.update!(org: nil)
    assert_nil @user.reload.org

    assert_no_difference 'Post.count' do
      post api_v1_posts_url, headers: @authorized_headers, params: @params
      assert_response :not_found
    end
  end

  test 'should index with valid authorization' do
    get api_v1_posts_url, headers: @authorized_headers
    assert_response :ok
  end

  test 'should not index with invalid authorization' do
    get api_v1_posts_url, headers: { Authorization: 'bad'}
    assert_response :unauthorized
  end

  test 'should not index if user is not in an Org' do
    @user.update!(org: nil)
    assert_nil @user.reload.org

    get api_v1_posts_url, headers: @authorized_headers
    assert_response :not_found
  end

  test 'index should include multiple posts' do
    get api_v1_posts_url, headers: @authorized_headers
    json_response = JSON.parse(response.body, symbolize_names: true)
    posts = json_response.dig(:posts)
    assert_operator posts.count, :>, 1
  end

  test 'index should only include posts from requester Org' do
    get api_v1_posts_url, headers: @authorized_headers
    json_response = JSON.parse(response.body, symbolize_names: true)
    post_jsons = json_response.dig(:posts)
    post_ids = post_jsons.map {|p| p[:id]}
    posts = Post.find(post_ids)
    posts.each do |post|
      assert_equal post.org, @user.org
    end
  end

  test 'index should format created_at attributes as iso8601' do
    get api_v1_posts_url, headers: @authorized_headers
    json_response = JSON.parse(response.body, symbolize_names: true)
    created_at = json_response.dig(:posts, 1, :created_at)
    assert Time.iso8601(created_at)
  end

  test 'index should include pagination metadata' do
    get api_v1_posts_url, headers: @authorized_headers
    json_response = JSON.parse(response.body, symbolize_names: true)
    metadata = json_response[:meta]
    assert json_response[:meta].key?(:current_page)
    assert json_response[:meta].key?(:next_page)
  end

  test 'index should respect page param' do
    page = 99
    get api_v1_posts_url, headers: @authorized_headers, params: { page: page }
    json_response = JSON.parse(response.body, symbolize_names: true)
    current_page = json_response.dig(:meta, :current_page)
    assert_equal page, current_page
  end
end
