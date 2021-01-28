class ApiParticulierBridge < BridgeService
  def initialize(enrollment)
    @enrollment = enrollment
  end

  def call
    name = "#{@enrollment.nom_raison_sociale} - #{@enrollment.id}"
    technical_contact_email = @enrollment.contacts.find { |contact| contact["id"] == "technique" }["email"]
    functionnal_contact_email = @enrollment.contacts.find { |contact| contact["id"] == "metier" }["email"]
    author_email = @enrollment.user[:email]
    scopes = @enrollment[:scopes].reject { |_, v| !v }.keys
    linked_token_manager_id = create_enrollment_in_token_manager(@enrollment.id, name, email, scopes)
    @enrollment.update({linked_token_manager_id: linked_token_manager_id})
  end

  private

  def create_enrollment_in_token_manager(id, name, email, scopes)
    response = Http.post(
      "#{ENV.fetch("PORTAIL_API_GOUV_FR_HOST")}/api-particulier/subscribe",
      {
        name: name,
        technical_contact_email: technical_contact_email,
        functionnal_contact_email: functionnal_contact_email,
        author_email: author_email,
        data_pass_id: id,
        scopes: scopes
      },
      ENV.fetch("PORTAIL_API_GOUV_FR_API_KEY"),
      "Portail api.gouv.fr",
      "X-Api-Key"
    )

    response.parse["id"]
  end
end
