require File.expand_path('../../../test_helper', __FILE__)
require File.expand_path('../../../fixtures/active_record', __FILE__)

class ArticleResource < JSONAPI::Resource
  model_name 'Post'

  def self.records(options)
    options[:context].posts
  end
end

class CatResource < JSONAPI::Resource
  attribute :id
  attribute :name
  attribute :breed

  has_one :mother, class_name: 'Cat'
  has_one :father, class_name: 'Cat'
end

class PersonWithCustomAssociatedRecordsResource < PersonResource
  def associated_records(association_name, context)
    :associated_records
  end
end

class PersonWithCustomAssociatedRecordsErrorResource < PersonResource
  class AuthorizationError < StandardError; end
  def associated_records(association_name, context)
    raise AuthorizationError
  end
end

class ResourceTest < MiniTest::Unit::TestCase
  def setup
    @post = Post.first
  end

  def test_model_name
    assert_equal(PostResource._model_name, 'Post')
  end

  def test_model
    assert_equal(PostResource._model_class, Post)
  end

  def test_model_alternate
    assert_equal(ArticleResource._model_class, Post)
  end

  def test_class_attributes
    attrs = CatResource._attributes
    assert_kind_of(Hash, attrs)
    assert_equal(attrs.keys.size, 3)
  end

  def test_class_assosications
    associations = CatResource._associations
    assert_kind_of(Hash, associations)
    assert_equal(associations.size, 2)
  end

  def test_find_with_customized_base_records
    author = Person.find(1)
    posts = ArticleResource.find([], context: author).map(&:model)

    assert(posts.include?(Post.find(1)))
    refute(posts.include?(Post.find(3)))
  end

  def test_associated_records
    author = Person.find(1)
    preferences = Preferences.first
    refute(preferences == nil)
    author.update! preferences: preferences
    author_resource = PersonResource.new(author)
    assert_equal(author_resource.preferences.model, preferences)

    author_resource = PersonWithCustomAssociatedRecordsResource.new(author)
    assert_equal(author_resource.preferences.model, :associated_records)

    author_resource = PersonWithCustomAssociatedRecordsErrorResource.new(author)
    assert_raises PersonWithCustomAssociatedRecordsErrorResource::AuthorizationError do
      author_resource.posts
    end
  end

  def test_find_by_key_with_customized_base_records
    author = Person.find(1)

    post = ArticleResource.find_by_key(1, context: author).model
    assert_equal(post, Post.find(1))

    assert_raises JSONAPI::Exceptions::RecordNotFound do
      ArticleResource.find_by_key(3, context: author).model
    end
  end

  def test_updateable_fields_does_not_include_id
    assert(!CatResource.updateable_fields.include?(:id))
  end
end
