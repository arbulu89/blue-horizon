# frozen_string_literal: true

require 'rails_helper'

describe SourceValidator do
  subject(:validator) { described_class.new }

  let(:terraform) { Terraform }
  let(:terraform_instance) { instance_double(Terraform) }

  before do
    allow(terraform).to receive(:new).and_return(terraform_instance)
  end

  context 'with terraform accessors' do
    it 'can retrieve the terraform instance' do
      expect(validator.terraform).to be terraform_instance
    end

    it 'can set the terraform instance' do
      another_terraform_instance = instance_double(Terraform)
      validator.terraform = another_terraform_instance
      expect(validator.terraform).not_to be terraform_instance
      expect(validator.terraform).to be another_terraform_instance
    end
  end

  context 'when calling validate multiple times' do
    it 'initializes Terraform once only' do
      allow(terraform_instance).to receive(:validate)

      record = Source.new
      validator.validate(record)
      validator.validate(record)

      expect(terraform).to have_received(:new).once
    end
  end

  context 'when terraform validation fails' do
    let(:msg) { 'some error message' }

    before do
      allow(terraform_instance).to receive(:validate).and_return msg
    end

    it 'records the validation error message' do
      record = Source.new
      validator.validate(record)

      expect(record.errors.added?(:terraform_syntax, msg)).to be true
    end
  end
end
