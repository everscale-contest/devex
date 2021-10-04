#include <nil/crypto3/zk/components/blueprint.hpp>
#include <nil/crypto3/zk/components/blueprint_variable.hpp>

#include <nil/crypto3/zk/components/hashes/knapsack/knapsack_component.hpp>
#include <nil/crypto3/zk/components/hashes/hmac_component.hpp>
#include <nil/crypto3/zk/components/disjunction.hpp>

#include "list_contains_component.hpp"

using namespace nil::crypto3;
using namespace nil::crypto3::zk::components;
//using namespace nil::crypto3::algebra;
using namespace nil::crypto3::zk::snark;


class circuit {
public:
    static const std::size_t SECRET_BITS_SIZE = 256;
    static const std::size_t PRIMARY_INPUT_SIZE = 13;
    static const std::size_t MAX_VOTERS = 10;
    static const std::size_t VOTE_MSG_LEN = 32;
    static const std::size_t HASH_MSG_LEN = 33;
    static const std::size_t ANONYMOUS_ID_MSG_LEN = 34;

public:
    template <typename FieldType>
    static blueprint<FieldType> generate_circuit_with_witness(
        const std::vector<typename FieldType::value_type> &hashes_field_elements,
        const std::vector<bool> &secret_bv,
        std::uint32_t vote_choice,
        std::size_t secret_hash_index,
        const typename FieldType::value_type &vote_choice_hmac_value,
        const typename FieldType::value_type &anonymous_id_value)
    {
        return generate_circuit_internal<FieldType>(
            hashes_field_elements,
            secret_bv,
            vote_choice,
            secret_hash_index,
            vote_choice_hmac_value,
            anonymous_id_value,
            true
        );
    }
    
    template <typename FieldType>
    static blueprint<FieldType> generate_circuit() {
        return generate_circuit_internal<FieldType>();
    }

private:
    template <typename FieldType>
    static blueprint<FieldType> generate_circuit_internal(
        const std::vector<typename FieldType::value_type> &hashes_field_elements={},
        const std::vector<bool> &secret_bv={},
        std::uint32_t vote_choice=0,
        std::size_t secret_hash_index = 0,
        const typename FieldType::value_type &vote_choice_hmac_value = 0,
        const typename FieldType::value_type &anonymous_id_value = 0,
        bool generate_witness = false
        ) {
        typedef hmac_component<FieldType,
                        knapsack_crh_with_bit_out_component<FieldType>,
                        knapsack_crh_with_field_out_component<FieldType>>
            Hmac;

        constexpr const std::size_t modulus_bits = FieldType::modulus_bits;
        constexpr const std::size_t modulus_chunks = modulus_bits / 8 + (modulus_bits % 8 ? 1 : 0);


        blueprint<FieldType> bp;
            // public input varibles

        // packed hashes of permitted voting secrets
        blueprint_variable_vector<FieldType> voting_secrets_hashes;
        voting_secrets_hashes.allocate(bp, MAX_VOTERS);
        // the vote choice, uint32
        blueprint_variable<FieldType> vote;
        vote.allocate(bp);
        // Hmac(secret,little endian vote)
        blueprint_variable<FieldType> vote_hmac;
        vote_hmac.allocate(bp);

        // Hmac(secret, ANONYMOUS_ID_MSG_LEN ones)
        blueprint_variable<FieldType> anonymous_id;
        anonymous_id.allocate(bp);
        assert(bp.num_variables() == PRIMARY_INPUT_SIZE);
        bp.set_input_sizes(PRIMARY_INPUT_SIZE);

        // auxilary input variables

        digest_variable<FieldType> voting_secret(bp, SECRET_BITS_SIZE);

        // components for verification of the voting secret.

        // Hmac(secret, HASH_MSG_LEN ones)
        blueprint_variable<FieldType> secret_hash;
        secret_hash.allocate(bp);
        block_variable<FieldType> secret_block(bp, {voting_secret.bits});

        // blueprint_variable not allocated, therfore constant and equal to 1.
        blueprint_variable<FieldType> one;

        block_variable<FieldType> hash_msg_block(bp,
            {blueprint_variable_vector<FieldType>(HASH_MSG_LEN, one)});
        Hmac secret_hmac_comp(bp,
                            secret_block,
                            hash_msg_block,
                            blueprint_variable_vector<FieldType>(1, secret_hash));
        
        // In case the voters list contains less than the maximum amount possible
        // we fill the rest with zeros.
        // So we have to make sure the secret's hash is not zero.
        blueprint_variable_vector<FieldType> secret_hash_bits;
        secret_hash_bits.allocate(bp, modulus_bits);
        packing_component<FieldType> secret_hash_pack(bp, secret_hash_bits, secret_hash);
        blueprint_variable<FieldType> not_all_zeros;
        not_all_zeros.allocate(bp);
        disjunction<FieldType> test_not_all_zeros(bp, secret_hash_bits, not_all_zeros);

        list_contains_component<FieldType> list_contains_comp(bp,
                                                            MAX_VOTERS,
                                                            voting_secrets_hashes,
                                                            secret_hash);

        // components for vote hmac

        blueprint_variable_vector<FieldType> vote_bits;
        vote_bits.allocate(bp, VOTE_MSG_LEN);
        packing_component<FieldType> vote_pack(bp, vote_bits, vote);
        block_variable<FieldType> vote_block(bp, {vote_bits});
        Hmac vote_hmac_component(bp, secret_block, vote_block, blueprint_variable_vector<FieldType>(1, vote_hmac));

        // componenets for verification of id

        block_variable<FieldType> anoynymous_id_msg_block(bp,
        {blueprint_variable_vector<FieldType>(ANONYMOUS_ID_MSG_LEN, one)});
        Hmac anonymous_id_msg_hmac(bp,
                        secret_block,
                        anoynymous_id_msg_block,
                        blueprint_variable_vector<FieldType>(1, anonymous_id));

        // generate constraints

        // constraints for verification of the voting secret.

        voting_secret.generate_r1cs_constraints();
        secret_hmac_comp.generate_r1cs_constraints();
        secret_hash_pack.generate_r1cs_constraints(true);
        test_not_all_zeros.generate_r1cs_constraints();
        generate_r1cs_equals_const_constraint<FieldType>(bp, not_all_zeros, 1);
        
        list_contains_comp.generate_r1cs_constraints();

        // constraints for vote hmac.

        vote_pack.generate_r1cs_constraints(true);
        vote_hmac_component.generate_r1cs_constraints();

        // constraints for id

        anonymous_id_msg_hmac.generate_r1cs_constraints();

        if(generate_witness) {
            assert(hashes_field_elements.size() == MAX_VOTERS);
            assert(secret_bv.size() == SECRET_BITS_SIZE);
            // generate witness
            
            for (size_t i = 0; i < hashes_field_elements.size(); i++) {
                bp.val(voting_secrets_hashes[i]) = hashes_field_elements[i];
            }

            voting_secret.generate_r1cs_witness(secret_bv);
            secret_hmac_comp.generate_r1cs_witness();
            secret_hash_pack.generate_r1cs_witness_from_packed();
            test_not_all_zeros.generate_r1cs_witness();

            list_contains_comp.generate_r1cs_witness(secret_hash_index);

            // witness generation for vote hmac
            bp.val(vote) = vote_choice;
            vote_pack.generate_r1cs_witness_from_packed();
            vote_hmac_component.generate_r1cs_witness();

            // witness generation for id

            anonymous_id_msg_hmac.generate_r1cs_witness();

            bp.val(vote_hmac) = vote_choice_hmac_value; 
            bp.val(anonymous_id) = anonymous_id_value;
        }

        return bp;
    }
};