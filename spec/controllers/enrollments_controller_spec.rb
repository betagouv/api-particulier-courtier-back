require 'rails_helper'

RSpec.describe EnrollmentsController, type: :controller do
  let(:uid) { 1 }
  let(:user) { FactoryGirl.create(:user, uid: uid) }
  before do
    user
    @request.headers['Authorization'] = 'Bearer test'
    stub_request(:get, 'http://test.host/api/v1/me')
    .with(
      headers: {
        'Accept' => '*/*',
        'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'Authorization' => 'Bearer test',
        'User-Agent' => 'Faraday v0.12.1'
      }
    ).to_return(status: 200, body: "{\"id\": #{uid}}", headers: {'Content-Type' => 'application/json'})
  end

  let(:enrollment) { FactoryGirl.create(:enrollment) }

  let(:valid_attributes) do
    enrollment.attributes
  end

  let(:invalid_attributes) do
    { agreement: false }
  end

  describe 'authentication' do
    it 'redirect to users/access_denied if oauth request fails' do
      stub_request(:get, 'http://test.host/api/v1/me')
      .with(
        headers: {
          'Accept' => '*/*',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Authorization' => 'Bearer test',
          'User-Agent' => 'Faraday v0.12.1'
        }
      ).to_return(status: 401, body: '', headers: {})

      get :index
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET #index' do
    it 'returns a success response' do
      get :index

      expect(response).to be_success
    end
  end

  describe 'GET #show' do
    it 'returns a success response' do
      get :show, params: { id: enrollment.to_param }

      expect(response).to have_http_status(:not_found)
    end

    describe 'with a france_connect user' do
      let(:uid) { 1 }
      let(:user) { FactoryGirl.create(:user, provider: 'france_connect', uid: uid) }

      before do
        @request.headers['Authorization'] = 'Bearer test'
        stub_request(:get, 'http://test.host/api/v1/me')
        .with(
          headers: {
            'Accept' => '*/*',
            'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'Authorization' => 'Bearer test',
            'User-Agent' => 'Faraday v0.12.1'
          }
        ).to_return(status: 200, body: "{\"id\": #{uid}}", headers: {'Content-Type' => 'application/json'})
      end

      describe 'user is applicant of enrollment' do
        before do
          user.add_role(:applicant, enrollment)
        end

        it 'returns a success response' do
          get :show, params: { id: enrollment.to_param }

          expect(response).to be_success
        end
      end

      describe 'user is not applicant of enrollment' do
        it 'returns a success response' do
          get :show, params: { id: enrollment.to_param }

          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  describe 'POST #create' do
    context 'with valid params' do
      it 'forbids enrollment creation' do
        post :create, params: { enrollment: valid_attributes }

        expect(response).to have_http_status(:forbidden)
      end
    end

    describe 'with a france_connect user' do
      let(:uid) { 1 }
      let(:user) { FactoryGirl.create(:user, provider: 'france_connect', uid: uid) }

      before do
        user
        @request.headers['Authorization'] = 'Bearer test'
        stub_request(:get, 'http://test.host/api/v1/me')
        .with(
          headers: {
            'Accept' => '*/*',
            'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'Authorization' => 'Bearer test',
            'User-Agent' => 'Faraday v0.12.1'
          }
        ).to_return(status: 200, body: "{\"id\": #{uid}}", headers: {'Content-Type' => 'application/json'})
      end

      context 'with valid params' do
        it 'creates a new Enrollment' do
          valid_attributes
          expect do
            post :create, params: { enrollment: valid_attributes }
          end.to change(Enrollment, :count).by(1)
        end

        it 'renders a JSON response with the new enrollment' do
          post :create, params: { enrollment: valid_attributes }

          expect(response).to have_http_status(:created)
          expect(response.content_type).to eq('application/json')
          expect(response.location).to eq(enrollment_url(Enrollment.last))
        end

        it 'user id applicant of enrollment' do
          post :create, params: { enrollment: valid_attributes }

          expect(user.has_role?(:applicant, Enrollment.last)).to be_truthy
        end
      end

      context 'with invalid params' do
        it 'renders a JSON response with errors for the new enrollment' do
          post :create, params: { enrollment: invalid_attributes }

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.content_type).to eq('application/json')
        end
      end

    end
  end

  describe 'PUT #update' do
    context 'with valid params' do
      let(:new_attributes) do
        { scopes: { tax_adress: true } }
      end

      let(:documents_attributes) do
        [{
          type: 'Document::LegalBasis',
          attachment: fixture_file_upload(Rails.root.join('spec/resources/test.pdf'), 'application/pdf')
        }]
      end

      after do
        DocumentUploader.new(Document, :attachment).remove!
      end

      it 'renders a not found' do
        put :update, params: { id: enrollment.to_param, enrollment: new_attributes }

        enrollment.reload
        expect(response).to have_http_status(:not_found)
      end

      describe 'with a france_connect user' do
        let(:uid) { 1 }
        let(:user) { FactoryGirl.create(:user, provider: 'france_connect', uid: uid) }

        before do
          @request.headers['Authorization'] = 'Bearer test'
          stub_request(:get, 'http://test.host/api/v1/me')
          .with(
            headers: {
              'Accept' => '*/*',
              'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'Authorization' => 'Bearer test',
              'User-Agent' => 'Faraday v0.12.1'
            }
          ).to_return(status: 200, body: "{\"id\": #{uid}}", headers: {'Content-Type' => 'application/json'})
        end

        describe 'user is not applicant of enrollment' do
          it 'renders a not found' do
            put :update, params: { id: enrollment.to_param, enrollment: new_attributes }

            enrollment.reload
            expect(response).to have_http_status(:not_found)
          end
        end

        describe 'user is applicant of enrollment' do
          before do
            user.add_role(:applicant, enrollment)
          end

          it 'updates the requested enrollment' do
            put :update, params: { id: enrollment.to_param, enrollment: new_attributes }

            enrollment.reload
            expect(enrollment.scopes['tax_adress']).to be_truthy
          end

          it 'renders a JSON response with the enrollment' do
            put :update, params: { id: enrollment.to_param, enrollment: valid_attributes }

            expect(response).to have_http_status(:ok)
            expect(response.content_type).to eq('application/json')
          end

          it 'creates an attached legal basis' do
            expect do
              put :update, params: {
                id: enrollment.to_param,
                enrollment: { documents_attributes: documents_attributes }
              }
            end.to(change { enrollment.documents.count })
          end
        end
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'renders a not found' do
      enrollment

      delete :destroy, params: { id: enrollment.to_param }

      expect(response).to have_http_status(:not_found)
    end

    describe 'with a france_connect user' do
      let(:uid) { 1 }
      let(:user) { FactoryGirl.create(:user, provider: 'france_connect', uid: uid) }

      before do
        @request.headers['Authorization'] = 'Bearer test'
        stub_request(:get, 'http://test.host/api/v1/me')
        .with(
          headers: {
            'Accept' => '*/*',
            'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'Authorization' => 'Bearer test',
            'User-Agent' => 'Faraday v0.12.1'
          }
      ).to_return(status: 200, body: "{\"id\": #{uid}}", headers: {'Content-Type' => 'application/json'})
      end

      describe 'user is not applicant of enrollment' do
        it 'renders a not found' do
          enrollment

          delete :destroy, params: { id: enrollment.to_param }

          expect(response).to have_http_status(:not_found)
        end
      end

      describe 'user is applicant of enrollment' do
        before do
          user.add_role(:applicant, enrollment)
        end

        it 'destroys the requested enrollment' do
          enrollment

          expect do
            delete :destroy, params: { id: enrollment.to_param }
          end.to change(Enrollment, :count).by(-1)
        end
      end
    end
  end
end