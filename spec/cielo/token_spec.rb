#encoding: utf-8
require 'spec_helper'

describe Cielo::Token do
  let(:card_params) { { :cartao_numero => '4012888888881881',  :cartao_validade => '201508', :cartao_portador => 'Nome portador' } }
  let(:generate_token_params) { { capturar: true, produto: 1, 'gerar-token': true, 'url-retorno': 'a.com', autorizar: 3, valor: 1323, numero: 5, moeda: 986, cartao_numero: 4012001037141112, cartao_validade: '201805', cartao_seguranca: 123, cartao_portador: 'Afranio', bandeira: 'visa' } }

  before do
    @token = Cielo::Token.new
  end

  describe "create a token for a card" do 
    before do
      Cielo.stub(:numero_afiliacao).and_return('1006993069')
      Cielo.stub(:chave_acesso).and_return('25fbb99741c739dd84d7b06ec78c9bac718838630f30b112d033ce2e621b34f3')

      @params = generate_token_params
    end

    it 'delivers an successful message and have a card token' do
      FakeWeb.register_uri(:any, 'https://ecommerce.cielo.com.br/servicos/ecommwsec.do',
        :body => "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><retorno-token versao=\"1.2.1\" id=\"57239017\" xmlns=\"http://ecommerce.cbmp.com.br\"><token><dados-token><codigo-token>TuS6LeBHWjqFFtE7S3zR052Jl/KUlD+tYJFpAdlA87E=</codigo-token><status>1</status><numero-cartao-truncado>455187******0183</numero-cartao-truncado></dados-token></token></retorno-token>", :content_type => "application/xml")
      
      response = @token.create! @params, :store
      
      response[:'retorno-token'][:token][:'dados-token'][:'codigo-token'].should_not be_nil
      response[:'retorno-token'][:token][:'dados-token'][:'numero-cartao-truncadov'].should_not be_nil

      # Respose type 
      # {:"retorno-token"=>{:token=>{:"dados-token"=>{:"codigo-token"=>"2ta/YqYaeyolf2NHkBWO8grPqZE44j3PvRAQxVQQGgE=", :status=>"1", :"numero-cartao-truncado"=>"401288******1881"}}}}
    end
  end

  describe 'charge with a generated token' do
    before do
      FakeWeb.allow_net_connect = true
      Cielo.environment = :production

      @secrets = Helper.secrets
      store_settings = @secrets[Cielo.environment.to_s]['store_settings']
      allow(Cielo).to receive(:numero_afiliacao).and_return(store_settings['membership'])
      allow(Cielo).to receive(:chave_acesso).and_return(store_settings['access_key'])
      @transaction = Cielo::Transaction.new

      mock_token_charged_json = '{"transacao":{"tid":"1063542305000000040A","pan":"OYV1BjLr7lL/jgE2qpPIg03YZhk7i/rUXy0ylv3ljp8=","dados-pedido":{"numero":"5","valor":"110","moeda":"986","data-hora":"2016-11-14T19:59:57.751-02:00","idioma":"PT","taxa-embarque":"0"},"forma-pagamento":{"bandeira":"visa","produto":"1","parcelas":"1"},"status":"6","autenticacao":{"codigo":"6","mensagem":"Transacao sem autenticacao","data-hora":"2016-11-14T19:59:57.769-02:00","valor":"110","eci":"7"},"autorizacao":{"codigo":"6","mensagem":"Transação autorizada","data-hora":"2016-11-14T19:59:57.776-02:00","valor":"110","lr":"00","arp":"786906","nsu":"000064"},"captura":{"codigo":"6","mensagem":"Transacao capturada com sucesso","data-hora":"2016-11-14T19:59:58.921-02:00","valor":"110"}}}'
      mock_generated_token_json = '{"transacao":{"tid":"106354230500000003CA","pan":"OYV1BjLr7lL/jgE2qpPIg03YZhk7i/rUXy0ylv3ljp8=","dados-pedido":{"numero":"5","valor":"110","moeda":"986","data-hora":"2016-11-14T19:57:09.257-02:00","idioma":"PT","taxa-embarque":"0"},"forma-pagamento":{"bandeira":"visa","produto":"1","parcelas":"1"},"status":"6","autenticacao":{"codigo":"6","mensagem":"Transacao sem autenticacao","data-hora":"2016-11-14T19:57:09.291-02:00","valor":"110","eci":"7"},"autorizacao":{"codigo":"6","mensagem":"Transação autorizada","data-hora":"2016-11-14T19:57:09.334-02:00","valor":"110","lr":"00","arp":"780914","nsu":"000060"},"captura":{"codigo":"6","mensagem":"Transacao capturada com sucesso","data-hora":"2016-11-14T19:57:10.427-02:00","valor":"110"},"token":{"dados-token":{"codigo-token":"44TyuILHFX+dtxOVvDdy2ypB5AfG8Cm93G7H9h2dKnw=","status":"1","numero-cartao-truncado":"498423******8979"}}}}'
      mock_generated_token = JSON.parse(mock_generated_token_json).deep_symbolize_keys
      mock_token_charged = JSON.parse(mock_token_charged_json).deep_symbolize_keys

      card = @secrets['production']['card']
      charge_gen_token_params = {
          capturar: true,
          produto: 1,
          'gerar-token': true,
          'url-retorno': 'a.com',
          autorizar: 3,
          valor: 110,
          numero: 5,
          moeda: 986,
          cartao_numero: card['number'],
          cartao_validade: card['expiration'],
          cartao_seguranca: card['cvv'],
          cartao_portador: card['holder'],
          bandeira: card['brand']
      }

      @generated_token = mock_generated_token
      # @generated_token = @transaction.create! charge_gen_token_params, :store
      @token_data = @generated_token[:transacao][:token][:'dados-token']

      base_generated_token_params = charge_gen_token_params.except(:'gerar-token', :cartao_validade, :cartao_seguranca, :cartao_portador, :cartao_numero)
      token_charge_params = base_generated_token_params.merge(token: @token_data[:'codigo-token'])

      # @token_charged = @transaction.create! token_charge_params, :store
      @token_charged = mock_token_charged

      # Expectation aux variables
      @generated_token_transaction = @generated_token[:transacao]
      @token_charged_transaction = @token_charged[:transacao]

      @token_charged_card_brand = @token_charged_transaction[:'forma-pagamento'][:bandeira]
      @generated_token_card_brand = @generated_token_transaction[:'forma-pagamento'][:bandeira]

      @token_charged_purchase = @token_charged_transaction[:'dados-pedido'][:numero]
      @generated_token_purchase = @generated_token_transaction[:'dados-pedido'][:numero]

      @token_charged_value = @token_charged_transaction[:'dados-pedido'][:valor]
      @generated_token_value = @generated_token_transaction[:'dados-pedido'][:valor]
    end

    it 'retrieves a successful token generated from a charge' do
      expect(@token_data[:'codigo-token']).to_not be_nil
      expect(@token_data[:'numero-cartao-truncado']).to_not be_nil
    end

    it 'must have a transaction with a valid TID' do
      expect(@token_charged_transaction).to_not be_nil
      expect(@token_charged_transaction[:tid]).to_not be_nil
    end

    it 'charged purchase token must be the same which generated it' do
      expect(@token_charged_purchase).to eq(@generated_token_purchase)
    end

    it 'charged token value must be the same the purchase generator value' do
      expect(@token_charged_value).to eq(@generated_token_value)
    end
  end

end
