# frozen_string_literal: true

FactoryGirl.define do
  factory :message do
    enrollment
    content 'MyText'
    user
  end
end
