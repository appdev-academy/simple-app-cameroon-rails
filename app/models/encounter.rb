class Encounter < ApplicationRecord
  include Mergeable
  include SQLHelpers

  belongs_to :patient, optional: true
  belongs_to :facility

  has_many :observations
  has_many :blood_pressures, through: :observations, source: :observable, source_type: "BloodPressure"
  has_many :blood_sugars, through: :observations, source: :observable, source_type: "BloodSugar"

  def self.generate_id(facility_id, patient_id, encountered_on)
    UUIDTools::UUID
      .sha1_create(UUIDTools::UUID_DNS_NAMESPACE,
        [facility_id, patient_id, encountered_on].join(""))
      .to_s
  end

  def self.generate_encountered_on(time, timezone_offset)
    time
      .to_time
      .utc
      .advance(seconds: timezone_offset)
      .to_date
  end

  def prescription_drugs
    end_of_day = encountered_on.end_of_day + timezone_offset.hours

    patient_prescription_drugs = PrescriptionDrug.where(
      is_protocol_drug: true,
      patient: patient
    )

    patient_prescription_drugs.select { |drug| drug.active_on?(encountered_on) }
  end
end
