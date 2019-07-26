class Enrollment::ApiEntreprisePolicy < EnrollmentPolicy
  def permitted_attributes
    res = super

    res.concat([
      scopes: [
        :associations,
        :attestations_agefiph,
        :attestations_fiscales,
        :attestations_sociales,
        :bilans_entreprise_bdf,
        :fntp_carte_pro,
        :certificat_cnetp,
        :msa_cotisations,
        :certificat_opqibi,
        :probtp,
        :qualibat,
        :certificat_rge_ademe,
        :documents_association,
        :exercices,
        :extrait_court_inpi,
        :extraits_rcs,
        :entreprises,
        :etablissements,
        :liasse_fiscale,
      ]
    ])

    res
  end
end
