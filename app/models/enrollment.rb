class Enrollment < ActiveRecord::Base
  self.inheritance_column = 'target_api'

  # enable Single Table Inheritance with target_api as discriminatory field
  class << self
    # ex: 'api_particulier' => Enrollment::ApiParticulier
    def find_sti_class(target_api)
      "Enrollment::#{target_api.underscore.classify}".constantize
    end

    # ex: Enrollment::ApiParticulier => 'api_particulier'
    def sti_name
      self.name.demodulize.underscore
    end
  end

  validate :update_validation

  before_save :clean_and_format_scopes
  before_save :set_company_info

  has_many :documents, as: :attachable
  accepts_nested_attributes_for :documents
  belongs_to :user
  has_many :events

  state_machine :status, initial: :pending do
    state :pending
    state :sent do
      validate :sent_validation
    end
    state :validated
    state :refused

    event :send_application do
      transition from: :pending, to: :sent
    end

    event :refuse_application do
      transition :sent => :refused
    end

    event :review_application do
      transition from: :sent, to: :pending
    end

    event :validate_application do
      transition from: :sent, to: :validated
    end

    before_transition all => all do |enrollment, transition|
      state_machine_event_to_event_names = {
          send_application: 'submitted',
          validate_application: 'validated',
          review_application: 'asked_for_modification',
          refuse_application: 'refused'
      }

      enrollment.events.create!(
          name: state_machine_event_to_event_names[transition.event],
          user_id: transition.args[0][:user_id],
          comment: transition.args[0][:comment]
      )
    end

    before_transition :sent => :validated do |enrollment, transition|
      if enrollment.target_api == 'api_particulier'
        RegisterApiParticulierEnrollment.call(enrollment)
      end

      if enrollment.target_api == 'franceconnect'
        RegisterFranceconnectEnrollment.call(enrollment)
      end

      if enrollment.target_api == 'dgfip'
        RegisterDgfipEnrollment.call(enrollment)
      end
    end

    event :loop_without_job do
      transition any => same
    end
  end

  def admins
    User.where('? = ANY(roles)', self.target_api)
  end

  protected

  def clean_and_format_scopes
    # we need to convert boolean values as it is send as string because of the data-form serialisation
    self.scopes = scopes.transform_values { |e| e.to_s == "true" }

    # in a similar way, format additional boolean content
    if additional_content.key?('dgfip_data_years')
      self.additional_content['dgfip_data_years'] =
          additional_content['dgfip_data_years'].transform_values { |e| e.to_s == "true" }
    end
    if additional_content.key?('rgpd_general_agreement')
      self.additional_content['rgpd_general_agreement'] =
          additional_content['rgpd_general_agreement'].to_s == "true"
    end
    if additional_content.key?('has_alternative_authentication_methods')
      self.additional_content['has_alternative_authentication_methods'] =
          additional_content['has_alternative_authentication_methods'].to_s == "true"
    end
  end

  def set_company_info
    escapedSpacelessSiret = CGI.escape(siret.delete(" \t\r\n"))
    url = URI("https://entreprise.data.gouv.fr/api/sirene/v1/siret/#{escapedSpacelessSiret}")

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Get.new(url)

    response = http.request(request)

    if response.code == '200'
      nom_raison_sociale = JSON.parse(response.read_body)["etablissement"]["nom_raison_sociale"]
      self.siret = escapedSpacelessSiret
      self.nom_raison_sociale = nom_raison_sociale
    else
      self.nom_raison_sociale = nil
    end
  end

  def update_validation
    errors[:intitule] << "Vous devez renseigner l'intitulé de la démarche avant de continuer" unless intitule.present?
    # the following 2 errors should never occur #defensiveprogramming
    errors[:target_api] << "Une erreur inattendue est survenue: pas d'API cible" unless target_api.present?
    errors[:organization_id] << "Une erreur inattendue est survenue: pas d'organisation" unless organization_id.present?
  end

  def sent_validation
    %w[dpo technique responsable_traitement]. each do |contact_type|
      contact = contacts&.find { |e| e['id'] == contact_type }
      errors[:contacts] << "Vous devez renseigner le #{contact&.fetch('heading', nil)} avant de continuer" unless contact&.fetch('nom', false)&.present? && contact&.fetch('email', false)&.present?
    end

    errors[:siret] << "Vous devez renseigner un SIRET d'organisation valide avant de continuer" unless nom_raison_sociale.present?
    errors[:cgu_approved] << "Vous devez valider les modalités d'utilisation avant de continuer" unless cgu_approved?
    errors[:description] << "Vous devez renseigner la description de la démarche avant de continuer" unless description.present?
    errors[:fondement_juridique_title] << "Vous devez renseigner le fondement juridique de la démarche avant de continuer" unless fondement_juridique_title.present?
    errors[:fondement_juridique_url] << "Vous devez renseigner le document associé au fondement juridique" unless (fondement_juridique_url.present?) || documents.where(type: 'Document::LegalBasis').present?
    errors[:base] << "Vous devez activer votre compte api.gouv.fr avant de continuer.
Merci de cliquer sur le lien d'activation que vous avez reçu par mail.
Vous pouvez également demander un nouveau lien d'activation en cliquant sur le lien
suivant #{ENV.fetch('OAUTH_HOST')}/users/send-email-verification?notification=email_verification_required" unless user.email_verified
  end
end
