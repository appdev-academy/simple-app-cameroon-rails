require 'rails_helper'
include Hashable

RSpec.describe PrescriptionDrug, type: :model do
  describe 'Validations' do
    it_behaves_like 'a record that validates device timestamps'
  end

  describe 'Associations' do
    it { should belong_to(:facility).optional }
    it { should belong_to(:patient).optional }
  end

  describe 'Behavior' do
    it_behaves_like 'a record that is deletable'
  end

  context 'anonymised data for prescription drugs' do
    describe 'anonymized_data' do
      it 'correctly retrieves the anonymised data for the prescription drug' do
        prescription_drug = create(:prescription_drug)

        anonymised_data =
          { id: hash_uuid(prescription_drug.id),
            patient_id: hash_uuid(prescription_drug.patient_id),
            created_at: prescription_drug.created_at,
            registration_facility_name: prescription_drug.facility.name,
            user_id: hash_uuid(prescription_drug.patient.registration_user.id),
            medicine_name: prescription_drug.name,
            dosage: prescription_drug.dosage }

        expect(prescription_drug.anonymized_data).to eq anonymised_data
      end
    end
  end

  describe '#active_on?' do
    it "is active if created before that day" do
      today = Time.now.to_date
      created_at = Time.now.beginning_of_day + 10.hours - 5.days
      prescription_drug = create(:prescription_drug, device_created_at: created_at)

      expect(prescription_drug.active_on?(today)).to eq(true)
    end
    it "is active if created on that day" do
      today = Time.now.to_date
      created_at = Time.now.beginning_of_day + 10.hours
      prescription_drug = create(:prescription_drug, device_created_at: created_at)

      expect(prescription_drug.active_on?(today)).to eq(true)
    end

    it "is active if deleted after that day" do
      today = Time.now.to_date
      created_at = Time.now.beginning_of_day + 10.hours - 5.days
      deleted_at = Time.now.beginning_of_day + 10.hours + 5.days
      prescription_drug = create(:prescription_drug, device_created_at: created_at, device_updated_at: deleted_at, is_deleted: true)

      expect(prescription_drug.active_on?(today)).to eq(true)
    end

    it "is active if not deleted" do
      today = Time.now.to_date
      created_at = Time.now.beginning_of_day + 10.hours - 5.days
      prescription_drug = create(:prescription_drug, device_created_at: created_at, device_updated_at: created_at, is_deleted: false)

      expect(prescription_drug.active_on?(today)).to eq(true)
    end

    it "is not active if created after that day" do
      today = Time.now.to_date
      created_at = Time.now.beginning_of_day + 10.hours + 1.day
      prescription_drug = create(:prescription_drug, device_created_at: created_at)

      expect(prescription_drug.active_on?(today)).to eq(false)
    end

    it "is not active if deleted before that day" do
      today = Time.now.to_date
      created_at = Time.now.beginning_of_day + 10.hours - 5.days
      deleted_at = Time.now.beginning_of_day + 10.hours - 1.day
      prescription_drug = create(:prescription_drug, device_created_at: created_at, device_updated_at: deleted_at, is_deleted: true)

      expect(prescription_drug.active_on?(today)).to eq(false)
    end

    it "is not active if deleted on that day" do
      today = Time.now.to_date
      created_at = Time.now.beginning_of_day + 10.hours - 5.days
      deleted_at = Time.now.beginning_of_day + 10.hours
      prescription_drug = create(:prescription_drug, device_created_at: created_at, device_updated_at: deleted_at, is_deleted: true)

      expect(prescription_drug.active_on?(today)).to eq(false)
    end
  end
end
