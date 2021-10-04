//---------------------------------------------------------------------------//
// Copyright (c) 2018-2021 Mikhail Komarov <nemo@nil.foundation>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//---------------------------------------------------------------------------//


#define PROVING_KEY_FILE "provkey.bin"
#define VERIFICATION_KEY_FILE "verifkey.bin"
#define BIG_PROOF_FILE "big_proof.bin"
#define PROOF_FILE "proof.bin"
#define PRIMARY_INPUT_FILE "primary_input.bin"

#include <iostream>

#include <boost/filesystem.hpp>
#include <boost/program_options.hpp>

#include "detail/r1cs_examples.hpp"
#include "detail/sha256_component.hpp"

#include <nil/crypto3/algebra/curves/bls12.hpp>
#include <nil/crypto3/algebra/fields/bls12/base_field.hpp>
#include <nil/crypto3/algebra/fields/bls12/scalar_field.hpp>
#include <nil/crypto3/algebra/fields/arithmetic_params/bls12.hpp>
#include <nil/crypto3/algebra/curves/params/multiexp/bls12.hpp>
#include <nil/crypto3/algebra/curves/params/wnaf/bls12.hpp>

#include <nil/crypto3/zk/components/blueprint.hpp>
#include <nil/crypto3/zk/components/blueprint_variable.hpp>

#include <nil/crypto3/zk/snark/schemes/ppzksnark/r1cs_gg_ppzksnark.hpp>
#include <nil/crypto3/zk/snark/schemes/ppzksnark/r1cs_gg_ppzksnark/marshalling.hpp>

#include <nil/crypto3/zk/snark/algorithms/generate.hpp>
#include <nil/crypto3/zk/snark/algorithms/verify.hpp>
#include <nil/crypto3/zk/snark/algorithms/prove.hpp>

#include <nil/crypto3/zk/components/component.hpp>

#include <nil/crypto3/zk/components/blueprint.hpp>
#include <nil/crypto3/zk/components/blueprint_variable.hpp>
// #include <nil/crypto3/zk/snark/components/basic_components.hpp>

// #include <nil/crypto3/zk/snark/relations/constraint_satisfaction_problems/r1cs.hpp>

using namespace nil::crypto3;
using namespace nil::crypto3::zk;
using namespace nil::crypto3::zk::components;
using namespace nil::crypto3::algebra;

#include <iostream>
#include <string>
#include "picosha2.hpp"

using namespace std;

typedef algebra::curves::bls12<381> curve_type;
typedef typename curve_type::scalar_field_type field_type;
typedef zk::snark::r1cs_gg_ppzksnark<curve_type> scheme_type;

using std::string;
using std::cout;
using std::endl;



using curve_type = curves::bls12<381>;
using field_type = typename curve_type::scalar_field_type;


// must be done here, after definition of curve_type and field_type
#include "utils.hpp"


void build_circuit ( blueprint<field_type> &bp,
                     std::vector<uint32_t> &passphrase32 ){

  blueprint_variable<field_type> public_pubkey0;
  public_pubkey0.allocate( bp );

  blueprint_variable<field_type> public_pubkey1;
  public_pubkey1.allocate( bp );

  blueprint_variable<field_type> public_pubkey2;
  public_pubkey2.allocate( bp );

  blueprint_variable<field_type> public_pubkey3;
  public_pubkey3.allocate( bp );

  blueprint_variable<field_type> secret_pubkey0;
  secret_pubkey0.allocate( bp );

  blueprint_variable<field_type> secret_pubkey1;
  secret_pubkey1.allocate( bp );

  blueprint_variable<field_type> secret_pubkey2;
  secret_pubkey2.allocate( bp );

  blueprint_variable<field_type> secret_pubkey3;
  secret_pubkey3.allocate( bp );

  blueprint_variable<field_type> secret_submission0;
  secret_submission0.allocate( bp );

  blueprint_variable<field_type> secret_submission1;
  secret_submission1.allocate( bp );

  blueprint_variable<field_type> secret_submission2;
  secret_submission2.allocate( bp );

  blueprint_variable<field_type> secret_submission3;
  secret_submission3.allocate( bp );

  bp.set_input_sizes(4);

  // This sets up the blueprint variables
  // so that the first one (out) represents the public
  // input and the rest is private input
  
  bp.add_r1cs_constraint(r1cs_constraint<field_type>( secret_pubkey0 , 1, public_pubkey0 ));
  bp.add_r1cs_constraint(r1cs_constraint<field_type>( secret_pubkey1 , 1, public_pubkey1 ));
  bp.add_r1cs_constraint(r1cs_constraint<field_type>( secret_pubkey2 , 1, public_pubkey2 ));
  bp.add_r1cs_constraint(r1cs_constraint<field_type>( secret_pubkey3 , 1, public_pubkey3 ));
  bp.add_r1cs_constraint(r1cs_constraint<field_type>( passphrase32[0] , 1, secret_submission0 ));
  bp.add_r1cs_constraint(r1cs_constraint<field_type>( passphrase32[1] , 1, secret_submission1 ));
  bp.add_r1cs_constraint(r1cs_constraint<field_type>( passphrase32[2] , 1, secret_submission2 ));
  bp.add_r1cs_constraint(r1cs_constraint<field_type>( passphrase32[3] , 1, secret_submission3 ));
}



void uint32s_of_solution( std::vector<uint32_t> &passphrase32,
                          std::string problem_s,
                          std::string nonce_s,
                          std::string solution_s )
{
  problem_s.append( nonce_s );
  problem_s.append( solution_s );
  std::cerr << "computing shas (~20 seconds)" << endl ;
  for( int i = 0 ; i < 1000000 ; i++ ){
    std::vector<uint8_t> hash(picosha2::k_digest_size);
    picosha2::hash256( problem_s.begin(), problem_s.end(),
                       hash.begin(), hash.end());
    std::ostringstream oss;
    output_hex(hash.begin(), hash.begin() + picosha2::k_digest_size, oss);
    problem_s.assign(oss.str());
  }
  std::cerr << "computing shas done" << endl ;
  
  uint32s_of_passphrase( passphrase32, problem_s );
}

void prepare_circuit ( std::string problem_s,
                       std::string nonce_s,
                       std::string solution_s ){

  using curve_type = curves::bls12<381>;
  using field_type = typename curve_type::scalar_field_type;

  std::vector<uint32_t> passphrase32(4);
  uint32s_of_solution( passphrase32, problem_s, nonce_s, solution_s );

  blueprint<field_type> bp;
  build_circuit( bp, passphrase32 );

  const r1cs_constraint_system<field_type> constraint_system =
    bp.get_constraint_system();
  const typename r1cs_gg_ppzksnark<curve_type>::keypair_type keypair =
    generate<r1cs_gg_ppzksnark<curve_type>>(constraint_system);

  save_proving_key( PROVING_KEY_FILE, keypair.first ) ;
  save_verification_key( VERIFICATION_KEY_FILE , keypair.second );

}

void use_circuit( std::string problem_s,
                  std::string nonce_s,
                  std::string submission_s,
                  std::string pubkey_s ){

  std::vector<uint32_t> pubkey32(4);
  if( pubkey_s.size() != 64 ){
    cerr << "Wrong size for pubkey, should be 64 hexa chars" << endl ;
    exit(2) ;
  }
  uint32s_of_pubkey( pubkey32, pubkey_s );

  std::vector<uint32_t> passphrase32(4);
  uint32s_of_solution( passphrase32, problem_s, nonce_s, submission_s );

  // public
  snark::r1cs_variable_assignment<field_type> primary_assignment;
  for( int i = 0; i < 4; i++){
    primary_assignment.push_back( pubkey32 [i] );
  }
  typename scheme_type::primary_input_type primary_input
    ( primary_assignment.begin(), primary_assignment.begin() + 4 );

  // private
  snark::r1cs_variable_assignment<field_type> auxiliary_assignment;
  for( int i = 0; i < 4; i++){
    auxiliary_assignment.push_back( pubkey32 [i] );
  }
  for( int i = 0; i < 4; i++){
    auxiliary_assignment.push_back( passphrase32 [i] );
  }

  typename scheme_type::auxiliary_input_type auxiliary_input
    ( auxiliary_assignment.begin(), auxiliary_assignment.begin() + 8 );


  typename scheme_type::proving_key_type pk =
    load_proving_key( PROVING_KEY_FILE );


  const typename r1cs_gg_ppzksnark<curve_type>::proof_type proof =
    prove<r1cs_gg_ppzksnark<curve_type>>( pk,  primary_input, auxiliary_input );

  const typename r1cs_gg_ppzksnark<curve_type>::verification_key_type vk =
    load_verification_key( VERIFICATION_KEY_FILE );

  bool verified =
    verify<r1cs_gg_ppzksnark<curve_type>>(vk, primary_input, proof);

  if( !verified ){
    cerr << "Invalid proof" << endl;
    exit(2) ;
  }

  save_primary_input( PRIMARY_INPUT_FILE, primary_input );
  save_big_proof( BIG_PROOF_FILE, proof, primary_input, vk );
  save_proof( PROOF_FILE, proof );

}

void print_usage(std::ostream &cout, std::string command )
{
    cout << command << " SUBCOMMAND [ARGUMENTS]" << endl ;
    cout << "Available subcommands:" << endl ;
    cout << "  * prepare PROBLEM NONCE SOLUTION : output circuit for PROBLEM with solution SOLUTION to 'provkey.bin' and 'verifkey.bin'" << endl ;
    cout << "  * prove PROBLEM NONCE SUBMISSION PUBKEY : generate 'proof.bin', 'verifkey.bin', 'variables.bin' and 'big_proof.bin'" << endl ;
    cout << "Arguments:" << endl ;
    cout << "  PROBLEM: the index of the Euler problem to solve (uint32)" << endl ;
    cout << "  NONCE: a big number unique to every problem" << endl ;
    cout << "  SOLUTION: the expected solution" << endl ;
    cout << "  SUBMISSION: the proposed solution" << endl ;
    cout << "  PUBKEY: the Hexadecimal representation of your pubkey (without 0x)" << endl ;

}

int main(int argc, char *argv[]) {

  if( argc == 1 ){
    print_usage ( cout, argv[0] ) ;
    return 0 ;
  }

  std::string subcommand = argv[1] ;
  if( subcommand == "prepare" ){
    cerr << "prepare" << endl ;
    if( argc != 5 ){
      cerr << "Bad number of arguments:" << endl ;
      print_usage ( cerr, argv[0] ) ;
      return 1;
    }

    prepare_circuit( argv[2], argv[3], argv[4] );
    return 0 ;
  } else
  if( subcommand == "prove" ){
    cerr << "prove" << endl ;
    if( argc != 6 ){
      cerr << "Bad number of arguments:" << endl ;
      print_usage ( cerr, argv[0] ) ;
      return 1;
    }
    use_circuit( argv[2], argv[3], argv[4], argv[5] );
    return 0 ;
  } else {
    cerr << "Unknown subcommand: " << subcommand << endl;
    return 2 ;
  }

}


/*
*/
