# frozen_string_literal: true
class Enrollment < ApplicationRecord
  DOCUMENT_TYPES = %w[
  ].freeze

  validate :abstract_class_validation
  validate :fournisseur_de_donnees_validation
  validate :agreements_validation

  has_many :messages
  accepts_nested_attributes_for :messages
  has_many :documents, as: :attachable
  accepts_nested_attributes_for :documents

  # Be aware with the duplication of attribute with type
  scope :api_particulier, -> { where(fournisseur_de_donnees: 'api-particulier') }
  scope :api_entreprise, -> { where(fournisseur_de_donnees: 'api-entreprise') }
  scope :dgfip, -> { where(fournisseur_de_donnees: 'dgfip') }

  state_machine :state, initial: :pending do
    before_transition any => any do |enrollment, transition|
      event = transition.event.to_s

      user = transition.args.first&.fetch(:user)
      user&.add_role(event.as_personified_event.to_sym, enrollment)

      begin
        job_class = "Enrollment::#{event.classify}Job".constantize
        job_class.perform_now(enrollment, user)
      rescue NameError => error
        Rails.logger.debug("No job (#{error.message}) found for #{enrollment.inspect}")
      end
    end

    state :pending
    state :sent
    state :validated
    state :refused
    state :technical_inputs
    state :deployed

    event :send_application do
      transition from: :pending, to: :sent
    end

    event :validate_application do
      transition from: :sent, to: :validated
    end

    event :refuse_application do
      transition from: :sent, to: :refused
    end

    event :review_application do
      transition from: :sent, to: :pending
    end

    event :send_technical_inputs do
      transition from: :validated, to: :technical_inputs
    end

    event :deploy_application do
      transition from: :technical_inputs, to: :deployed
    end

    event :loop_without_job do
      transition any => same
    end
  end

  def other_party(user)
    if user.has_role?(:applicant, self)
      provider = self.class.name.underscore.split('/').last
      return User.where(provider: provider)
    end

    User.with_role(:applicant, self)
  end

  def can_send_technical_inputs?
    return false if self.class.abstract?
    super
  end

  def applicant
    User.with_role(:applicant, self).first
  end

  def short_workflow?
    false
  end

  def self.with_role(type, user)
    return super(type, user) unless abstract?
    Rails.application.eager_load!

    enrollment_ids = descendants.map do |klass|
      klass.with_role(type, user).pluck(:id)
    end.flatten

    where(id: enrollment_ids)
  end

  def self.abstract?
    name == 'Enrollment'
  end

  def as_json(*params)
    {
      'updated_at' => updated_at,
      'created_at' => created_at
    }
  end

  protected

  def fournisseur_de_donnees_validation
    errors[:demarche] << "Vous devez renseigner l'intitulé de la démarche avant de continuer" unless demarche&.fetch('intitule', nil).present?
    errors[:fournisseur_de_donnees] << "Vous devez renseigner le fournisseur de données avant de continuer" unless fournisseur_de_donnees.present?
  end

  def agreements_validation
    errors[:validation_de_convention] << "Vous devez valider la convention avant de continuer" unless validation_de_convention?
  end

  def abstract_class_validation
    errors[:base] << "Vous devez fournir un type d'enrôlement" if self.class.abstract?
  end
end
