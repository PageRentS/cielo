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
      store_settings = @secrets['production']['store_settings']
      Cielo.stub(:numero_afiliacao).and_return(store_settings['membership'])
      Cielo.stub(:chave_acesso).and_return(store_settings['access_key'])

      @transaction = Cielo::Transaction.new


      card = @secrets['production']['card']
      production_params = {
          capturar: true,
          produto: 1,
          'gerar-token': true,
          'url-retorno': 'a.com',
          autorizar: 3,
          valor: 1,
          numero: 5,
          moeda: 986,
          cartao_numero: card['number'],
          cartao_validade: card['expiration'],
          cartao_seguranca: card['cvv'],
          cartao_portador: card['holder'],
          bandeira: card['brand']
      }

      # @generated_token = @transaction.create! generate_token_params, :store
      @generated_token = @transaction.create! production_params, :store

      token_charge_params = {
        capturar: true,
        produto: 1,
        'gerar-token': true,
        'url-retorno': 'a.com',
        autorizar: 3,
        valor: 1,
        numero: 5,
        moeda: 986,
        bandeira: 'visa',
        token: @generated_token[:transacao][:token][:'dados-token'][:'codigo-token']
      }

      @token_charged = @transaction.create! token_charge_params, :store
    end

    it 'retrieves a successful token generated from a charge' do
      expect(@generated_token[:'retorno-token'][:token][:'dados-token'][:'codigo-token']).to_not be_nil
      expect(@generated_token[:'retorno-token'][:token][:'dados-token'][:'numero-cartao-truncadov']).to_not be_nil
    end

    it 'charges using the previous generated token' do
      expect(@token_charged).to_not be_nil
      expect(@token_charged[:erro]).to be_nil
    end
  end

end
