require "rails_helper"

RSpec.describe ControlRateService, type: :model do
  let(:organization) { create(:organization, name: "org-1") }
  let(:user) { create(:admin, :manager, :with_access, resource: organization, organization: organization) }
  let(:facility_group_1) { FactoryBot.create(:facility_group, name: "facility_group_1", organization: organization) }

  let(:june_1_2018) { Time.parse("June 1, 2018 00:00:00+00:00") }
  let(:june_1_2020) { Time.parse("June 1, 2020 00:00:00+00:00") }
  let(:june_30_2020) { Time.parse("June 30, 2020 00:00:00+00:00") }
  let(:july_2020) { Time.parse("July 15, 2020 00:00:00+00:00") }
  let(:jan_2019) { Time.parse("January 1st, 2019 00:00:00+00:00") }
  let(:jan_2020) { Time.parse("January 1st, 2020 00:00:00+00:00") }
  let(:july_2018) { Time.parse("July 1st, 2018 00:00:00+00:00") }
  let(:july_2020) { Time.parse("July 1st, 2020 00:00:00+00:00") }

  def refresh_views
    ActiveRecord::Base.transaction do
      LatestBloodPressuresPerPatientPerMonth.refresh
      LatestBloodPressuresPerPatientPerQuarter.refresh
      PatientRegistrationsPerDayPerFacility.refresh
    end
  end

  it "counts registrations and cumulative registrations" do
    facility = FactoryBot.create(:facility, facility_group: facility_group_1)
    Timecop.freeze("January 1st 2018") do
      create_list(:patient, 2, recorded_at: Time.current, registration_facility: facility, assigned_facility: facility, registration_user: user)
    end
    Timecop.freeze("May 30th 2018") do
      create_list(:patient, 2, recorded_at: Time.current, registration_facility: facility, assigned_facility: facility, registration_user: user)
    end
    Timecop.freeze(june_1_2018) do
      create_list(:patient, 2, recorded_at: Time.current, registration_facility: facility, assigned_facility: facility, registration_user: user)
    end
    Timecop.freeze("April 15th 2020") do
      create_list(:patient, 2, recorded_at: Time.current, registration_facility: facility, assigned_facility: facility, registration_user: user)
    end
    Timecop.freeze("May 1 2020") do
      create_list(:patient, 3, recorded_at: Time.current, registration_facility: facility, assigned_facility: facility, registration_user: user)
      create_list(:patient, 1, recorded_at: Time.current, registration_facility: facility, assigned_facility: create(:facility), registration_user: user)
    end

    Timecop.freeze(june_30_2020) do
      create_list(:patient, 4, recorded_at: Time.current, registration_facility: facility, assigned_facility: facility, registration_user: user)
    end

    refresh_views

    range = (Period.month(june_1_2018)..Period.month(june_30_2020))
    service = ControlRateService.new(facility_group_1, periods: range)
    result = service.call
    april_period = Date.parse("April 1 2020").to_period
    may_period = Date.parse("May 1 2020").to_period
    june_period = Date.parse("June 1 2020").to_period
    expect(result[:registrations][june_1_2018.to_date.to_period]).to eq(2)
    expect(result[:assigned_patients][june_1_2018.to_date.to_period]).to eq(2)
    expect(result[:cumulative_registrations][june_1_2018.to_date.to_period]).to eq(6)
    expect(result[:cumulative_assigned_patients][june_1_2018.to_date.to_period]).to eq(6)
    expect(result[:registrations][april_period]).to eq(2)
    expect(result[:assigned_patients][april_period]).to eq(2)
    expect(result[:cumulative_registrations][april_period]).to eq(8)
    expect(result[:cumulative_assigned_patients][april_period]).to eq(8)
    expect(result[:registrations][may_period]).to eq(4)
    expect(result[:assigned_patients][may_period]).to eq(3)
    expect(result[:cumulative_registrations][may_period]).to eq(12)
    expect(result[:cumulative_assigned_patients][may_period]).to eq(11)
    expect(result[:registrations][june_period]).to eq(4)
    expect(result[:assigned_patients][june_period]).to eq(4)
    expect(result[:cumulative_registrations][june_period]).to eq(16)
    expect(result[:cumulative_assigned_patients][june_period]).to eq(15)
  end

  it "does not include months without registration data" do
    facility = FactoryBot.create(:facility, facility_group: facility_group_1)
    Timecop.freeze("April 15th 2020") do
      patients_with_controlled_bp = create_list(:patient, 2, recorded_at: 1.month.ago, registration_facility: facility, registration_user: user)
      patients_with_controlled_bp.map do |patient|
        create(:blood_pressure, :under_control, facility: facility, patient: patient, recorded_at: Time.current, user: user)
        create(:blood_pressure, :under_control, facility: facility, patient: patient, recorded_at: Time.current, user: user)
      end
    end

    refresh_views

    range = (Period.month(july_2018)..Period.month(june_1_2020))
    result = nil
    Timecop.freeze("July 1st 2020") do
      service = ControlRateService.new(facility_group_1, periods: range)
      result = service.call
    end
    expect(result[:cumulative_registrations].size).to eq(4)
    expect(result[:registrations].size).to eq(1)
    expect(result[:controlled_patients].size).to eq(4)
  end

  it "correctly returns controlled patients for past months" do
    facilities = FactoryBot.create_list(:facility, 5, facility_group: facility_group_1)
    facility = facilities.first
    facility_2 = create(:facility)

    controlled_in_jan_and_june = create_list(:patient, 2, full_name: "controlled", recorded_at: jan_2019, registration_facility: facility, registration_user: user)
    uncontrolled_in_jan = create_list(:patient, 2, full_name: "uncontrolled", recorded_at: jan_2019, registration_facility: facility, registration_user: user)
    controlled_just_for_june = create(:patient, full_name: "just for june", recorded_at: jan_2019, registration_facility: facility, registration_user: user)
    patient_from_other_facility = create(:patient, full_name: "other facility", recorded_at: jan_2019, registration_facility: facility_2, registration_user: user)

    Timecop.freeze(jan_2020) do
      controlled_in_jan_and_june.map do |patient|
        create(:blood_pressure, :under_control, facility: facility, patient: patient, recorded_at: 2.days.ago, user: user)
        create(:blood_pressure, :hypertensive, facility: facility, patient: patient, recorded_at: 4.days.ago, user: user)
      end
      uncontrolled_in_jan.map { |patient| create(:blood_pressure, :hypertensive, facility: facility, patient: patient, recorded_at: 4.days.ago) }
      create(:blood_pressure, :under_control, facility: facility, patient: patient_from_other_facility, recorded_at: 2.days.ago)
    end

    Timecop.freeze(june_1_2020) do
      controlled_in_jan_and_june.map do |patient|
        create(:blood_pressure, :under_control, facility: facility, patient: patient, recorded_at: 2.days.ago, user: user)
        create(:blood_pressure, :hypertensive, facility: facility, patient: patient, recorded_at: 4.days.ago, user: user)
        create(:blood_pressure, :hypertensive, facility: facility, patient: patient, recorded_at: 35.days.ago, user: user)
      end

      create(:blood_pressure, :under_control, facility: facility, patient: controlled_just_for_june, recorded_at: 4.days.ago, user: user)

      # register 5 more patients in feb 2020
      uncontrolled_in_june = create_list(:patient, 5, recorded_at: 4.months.ago, registration_facility: facility, registration_user: user)
      uncontrolled_in_june.map do |patient|
        create(:blood_pressure, :hypertensive, facility: facility, patient: patient, recorded_at: 1.days.ago, user: user)
        create(:blood_pressure, :under_control, facility: facility, patient: patient, recorded_at: 2.days.ago, user: user)
      end
    end

    refresh_views

    start_range = july_2020.advance(months: -24)
    service = ControlRateService.new(facility_group_1, periods: (Period.month(start_range)..Period.month(july_2020)))
    result = service.call

    expect(result[:registrations][Period.month(jan_2019)]).to eq(5)
    expect(result[:assigned_patients][Period.month(jan_2019)]).to eq(5)
    expect(result[:cumulative_registrations][Period.month(jan_2019)]).to eq(5)
    expect(result[:cumulative_assigned_patients][Period.month(jan_2019)]).to eq(5)
    expect(result[:adjusted_registrations][Period.month(jan_2019)]).to eq(0)

    expect(result[:cumulative_registrations][Period.month(jan_2020)]).to eq(5)
    expect(result[:cumulative_assigned_patients][Period.month(jan_2020)]).to eq(5)
    expect(result[:adjusted_registrations][Period.month(jan_2020)]).to eq(5)
    expect(result[:controlled_patients][Period.month(jan_2020)]).to eq(controlled_in_jan_and_june.size)
    expect(result[:controlled_patients_rate][Period.month(jan_2020)]).to eq(40.0)

    # 3 controlled patients in june and 10 cumulative registered patients
    expect(result[:cumulative_registrations][Period.month(june_1_2020)]).to eq(10)
    expect(result[:cumulative_assigned_patients][Period.month(june_1_2020)]).to eq(10)
    expect(result[:registrations][Period.month(june_1_2020)]).to eq(0)
    expect(result[:assigned_patients][Period.month(june_1_2020)]).to eq(0)
    expect(result[:controlled_patients][Period.month(june_1_2020)]).to eq(3)
    expect(result[:controlled_patients_rate][Period.month(june_1_2020)]).to eq(30.0)
    expect(result[:uncontrolled_patients][Period.month(june_1_2020)]).to eq(5)
    expect(result[:uncontrolled_patients_rate][Period.month(june_1_2020)]).to eq(50.0)
  end

  it "excludes patients registered in the last 3 months" do
    facility = FactoryBot.create(:facility, facility_group: facility_group_1)

    controlled_jan2020_registration = create(:patient, full_name: "controlled jan2020 registration", recorded_at: jan_2020, registration_facility: facility, registration_user: user)

    Timecop.freeze(jan_2020) do
      create(:blood_pressure, :under_control, facility: facility, patient: controlled_jan2020_registration, recorded_at: 2.days.ago)
    end

    refresh_views

    start_range = july_2020.advance(months: -24)
    service = ControlRateService.new(facility_group_1, periods: (Period.month(start_range)..Period.month(july_2020)))
    result = service.call

    expect(result[:registrations][Period.month(jan_2020)]).to eq(1)
    expect(result[:cumulative_registrations][Period.month(jan_2020)]).to eq(1)
    expect(result[:adjusted_registrations][Period.month(jan_2020)]).to eq(0)
    expect(result[:controlled_patients][Period.month(jan_2020)]).to eq(0)
    expect(result[:controlled_patients_rate][Period.month(jan_2020)]).to eq(0.0)
  end

  context "when with_exclusions is true" do
    it "excludes patients who are dead or LTFU" do
      facility = FactoryBot.create(:facility, facility_group: facility_group_1)
      patients = [
        create(:patient, recorded_at: jan_2019, registration_facility: facility, registration_user: user),
        create(:patient, status: :dead, recorded_at: jan_2019, registration_facility: facility, registration_user: user)
      ]

      Timecop.freeze(june_1_2020) do
        patients.each do |patient|
          create(:blood_pressure, :under_control, facility: facility, patient: patient, recorded_at: 2.days.ago, user: user)
        end
      end

      refresh_views

      report_start = july_2020.advance(months: -24)
      report_range = (Period.month(report_start)..Period.month(july_2020))
      report_month = Period.month(june_1_2020)

      result =
        ControlRateService.new(facility_group_1, periods: report_range).call

      expect(result[:cumulative_registrations][report_month]).to eq(2)
      expect(result[:cumulative_assigned_patients][report_month]).to eq(2)
      expect(result[:adjusted_registrations][report_month]).to eq(2)
      expect(result[:controlled_patients][report_month]).to eq(2)
      expect(result[:controlled_patients_rate][report_month]).to eq(100.0)
      expect(result[:uncontrolled_patients][report_month]).to eq(0)
      expect(result[:uncontrolled_patients_rate][report_month]).to eq(0)

      result_with_exclusions =
        ControlRateService.new(facility_group_1, periods: report_range, with_exclusions: true).call

      expect(result_with_exclusions[:cumulative_registrations][report_month]).to eq(2)
      expect(result_with_exclusions[:cumulative_assigned_patients][report_month]).to eq(1)
      expect(result_with_exclusions[:adjusted_registrations_with_ltfu][report_month]).to eq(1)
      expect(result_with_exclusions[:adjusted_registrations][report_month]).to eq(1)
      expect(result_with_exclusions[:controlled_patients][report_month]).to eq(1)
      expect(result_with_exclusions[:controlled_patients_rate][report_month]).to eq(100.0)
      expect(result_with_exclusions[:controlled_patients_with_ltfu_rate][report_month]).to eq(100.0)
      expect(result_with_exclusions[:uncontrolled_patients][report_month]).to eq(0)
      expect(result_with_exclusions[:uncontrolled_patients_rate][report_month]).to eq(0)
    end
  end

  it "quarterly control rate looks only at patients registered in the previous quarter" do
    facilities = FactoryBot.create_list(:facility, 5, facility_group: facility_group_1)
    facility = facilities.first
    facility_2 = create(:facility)

    controlled_in_q1 = create_list(:patient, 3, recorded_at: jan_2020, assigned_facility: facility, registration_user: user)
    controlled_in_q1.each do |patient|
      create(:blood_pressure, :under_control, facility: facility, patient: patient, recorded_at: Time.parse("September 1 2020"), user: user)
    end

    controlled_in_q3 = create_list(:patient, 3, recorded_at: june_1_2020, assigned_facility: facility, registration_user: user)
    controlled_in_q3.each do |patient|
      create(:blood_pressure, :under_control, facility: facility, patient: patient, recorded_at: Time.parse("September 1 2020"), user: user)
    end

    controlled_in_q3_other_facility = create_list(:patient, 3, recorded_at: june_1_2020, assigned_facility: facility_2, registration_user: user)
    controlled_in_q3_other_facility.each do |patient|
      create(:blood_pressure, :under_control, facility: facility_2, patient: patient, recorded_at: Time.parse("September 1 2020"), user: user)
    end

    uncontrolled_in_q3 = create_list(:patient, 7, recorded_at: june_1_2020, assigned_facility: facility, registration_user: user)
    uncontrolled_in_q3.each do |patient|
      create(:blood_pressure, :hypertensive, facility: facility, patient: patient, recorded_at: Time.parse("September 1 2020"), user: user)
    end

    refresh_views

    periods = Period.quarter(july_2018)..Period.quarter(july_2020)
    service = ControlRateService.new(facility_group_1, periods: periods)
    result = service.call

    # expect(result[:registrations].keys.size).to eq(3) # 3 quarters of data
    # expect(result[:registrations].keys.first.to_s).to eq("Q1-2020")
    # expect(result[:registrations].keys.last.to_s).to eq("Q3-2020")

    q3_2020 = Period.quarter("Q3-2020")
    # expect(result[:registrations][q3_2020]).to eq(10)
    expect(result[:controlled_patients][q3_2020]).to eq(3)
    expect(result[:controlled_patients_rate][q3_2020]).to eq(30.0)
    expect(result[:uncontrolled_patients][q3_2020]).to eq(7)
    expect(result[:uncontrolled_patients_rate][q3_2020]).to eq(70.0)
  end

  it "returns control rate for a single facility" do
    facilities = FactoryBot.create_list(:facility, 2, facility_group: facility_group_1)
    facility = facilities.first

    controlled = create_list(:patient, 2, full_name: "controlled", recorded_at: jan_2019,
                                          registration_facility: facility, registration_user: user)
    uncontrolled = create_list(:patient, 4, full_name: "uncontrolled", recorded_at: jan_2019,
                                            registration_facility: facility, registration_user: user)
    patient_from_other_facility = create(:patient, full_name: "other facility", recorded_at: jan_2019,
                                                   registration_facility: facilities.last, registration_user: user)

    Timecop.freeze(jan_2020) do
      controlled.map do |patient|
        create(:blood_pressure, :under_control, facility: facility, patient: patient, recorded_at: 2.days.ago, user: user)
        create(:blood_pressure, :hypertensive, facility: facility, patient: patient, recorded_at: 4.days.ago, user: user)
      end
      uncontrolled.map do |patient|
        create(:blood_pressure, :hypertensive, facility: facility,
                                               patient: patient, recorded_at: 4.days.ago, user: user)
      end
      create(:blood_pressure, :under_control, facility: facility, patient: patient_from_other_facility,
                                              recorded_at: 2.days.ago, user: user)
    end

    refresh_views

    periods = Period.month(july_2018)..Period.month(july_2020)
    service = ControlRateService.new(facility, periods: periods)
    result = service.call

    expect(result[:registrations][Period.month(jan_2019)]).to eq(6)
    expect(result[:controlled_patients][Period.month(jan_2020)]).to eq(controlled.size)
    expect(result[:controlled_patients_rate][Period.month(jan_2020)]).to eq(33)
  end

  it "returns registrations and control rates for a block" do
    brooklyn_facilities = FactoryBot.create_list(:facility, 2, block: "Brooklyn", facility_group: facility_group_1)
    queens_facility = FactoryBot.create(:facility, block: "Queens", facility_group: facility_group_1)
    facility_1, facility_2 = brooklyn_facilities[0], brooklyn_facilities[1]

    controlled_in_facility_1 = create_list(:patient, 2, full_name: "controlled", recorded_at: jan_2019,
                                                        registration_facility: facility_1, registration_user: user)
    uncontrolled_in_facility_1 = create_list(:patient, 4, full_name: "uncontrolled", recorded_at: jan_2019,
                                                          registration_facility: facility_1, registration_user: user)
    controlled_in_facility_2 = create_list(:patient, 2, full_name: "other facility", recorded_at: jan_2019,
                                                        registration_facility: facility_2, registration_user: user)
    patient_from_other_block = create(:patient, full_name: "other block", recorded_at: jan_2019,
                                                registration_facility: queens_facility, registration_user: user)

    # sanity checks for proper amount of regions
    expect(Region.state_regions.count).to eq(1)
    expect(Region.count).to eq(9) # 1 root, 1 org, 1 state, 1 district, 2 blocks, 3 facilities

    Timecop.freeze(jan_2020) do
      (controlled_in_facility_1 + controlled_in_facility_2).map do |patient|
        create(:blood_pressure, :under_control, facility: patient.registration_facility, patient: patient, recorded_at: 2.days.ago, user: user)
        create(:blood_pressure, :hypertensive, facility: patient.registration_facility, patient: patient, recorded_at: 4.days.ago, user: user)
      end
      uncontrolled_in_facility_1.map do |patient|
        create(:blood_pressure, :hypertensive, facility: patient.registration_facility,
                                               patient: patient, recorded_at: 4.days.ago, user: user)
      end
      create(:blood_pressure, :under_control, facility: queens_facility, patient: patient_from_other_block,
                                              recorded_at: 2.days.ago, user: user)
    end

    refresh_views

    periods = Period.month(july_2018)..Period.month(july_2020)
    service = ControlRateService.new(facility_1.block_region, periods: periods)
    result = service.call

    expect(result[:registrations][Period.month(jan_2019)]).to eq(8)
    expect(result[:controlled_patients][Period.month(jan_2020)]).to eq(4)
    expect(result[:controlled_patients_rate][Period.month(jan_2020)]).to eq(50)
  end

  context "caching" do
    let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
    let(:cache) { Rails.cache }

    before do
      allow(Rails).to receive(:cache).and_return(memory_store)
      Rails.cache.clear
    end

    it "has a cache key that distinguishes based on period" do
      region = facility_group_1.region

      month_periods = Period.month("September 1 2018")..Period.month("September 1 2020")
      earlier_month_periods = Period.month("January 1 2018")..Period.month("January 1 2020")
      quarter_periods = Period.quarter(july_2018)..Period.quarter(july_2020)
      Timecop.freeze("October 1 2020") do
        service_1 = ControlRateService.new(facility_group_1, periods: month_periods)
        expect(service_1.send(:cache_key)).to match(/regions\/district\/#{region.id}\/month/)

        service_2 = ControlRateService.new(facility_group_1, periods: earlier_month_periods)
        expect(service_2.send(:cache_key)).to match(/regions\/district\/#{region.id}\/month/)

        service_3 = ControlRateService.new(facility_group_1, periods: quarter_periods)
        expect(service_3.send(:cache_key)).to match(/regions\/district\/#{region.id}\/quarter/)
      end
    end
  end
end
