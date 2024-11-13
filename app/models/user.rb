# frozen_string_literal: true

class User < ApplicationRecord
  acts_as_token_authenticatable

  # Include default devise modules. Others available are:
  # :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :validatable,
    :trackable, :confirmable, :lockable, :timeoutable

  has_many :passwords, dependent: :destroy
  has_many :file_pushes, dependent: :destroy
  has_many :urls, dependent: :destroy

  def admin?
    admin
  end
end
