"""
    This file was generated by TONDev.
    TONDev is a part of TON OS (see http://ton.dev).
"""
from tonos_ts4 import ts4


def test():
    voters_set = [int(l, 16) for l in open('../hash-list').readlines()]

    constructor_params = {'voters_set': voters_set, 'num_options': 2}
    AnonymousVote = ts4.BaseContract('AnonymousVote', constructor_params, keypair=ts4.make_keypair())

    proof = ts4.Bytes(open('../proof', 'rb').read().hex())
    AnonymousVote.call_method('vote', {
        'proof': proof,
        'vote_choice': 0,
        'signed_vote': 0xE7EA50574F6E21467915257BC3BFA4B1B7315BF2E29F9DD6F5E53C9B99595A51,
        'anonymous_id': 0xFCEFE3D2B1EEFC9A506B167151E81AE248F31DE896AD48DC6DCC5F4805373B5A
    })

    assert AnonymousVote.call_getter('get_results') == {0:1}
    assert AnonymousVote.call_getter('get_vote', {
        'anonymous_id': 0xFCEFE3D2B1EEFC9A506B167151E81AE248F31DE896AD48DC6DCC5F4805373B5A
    }) == (True, 0)
    assert AnonymousVote.call_getter('get_vote', {
        'anonymous_id': 0x03028200952785FA92B6925F22270C139E3BDD3CC0A9EACF39B5987AFB531039
    }) == (False, 0)
    proof2 = ts4.Bytes(open('../proof2', 'rb').read().hex())
    AnonymousVote.call_method('vote', {
        'proof': proof2,
        'vote_choice': 0,
        'signed_vote': 0x03040B9229613FB97333325A055681A7A0942C36354C63A1861693174D4FDC16,
        'anonymous_id': 0x03028200952785FA92B6925F22270C139E3BDD3CC0A9EACF39B5987AFB531039
    })
    assert AnonymousVote.call_getter('get_results') == {0:2}
    assert AnonymousVote.call_getter('get_vote', {
        'anonymous_id': 0xFCEFE3D2B1EEFC9A506B167151E81AE248F31DE896AD48DC6DCC5F4805373B5A
    }) == (True, 0)
    assert AnonymousVote.call_getter('get_vote', {
        'anonymous_id': 0x03028200952785FA92B6925F22270C139E3BDD3CC0A9EACF39B5987AFB531039
    }) == (True, 0)

    AnonymousVote.call_method('vote', {
        'proof': proof,
        'vote_choice': 0,
        'signed_vote': 0xE7EA50574F6E21467915257BC3BFA4B1B7315BF2E29F9DD6F5E53C9B99595A51,
        'anonymous_id': 0xFCEFE3D2B1EEFC9A506B167151E81AE248F31DE896AD48DC6DCC5F4805373B5A
    }, expect_ec=109)

    assert AnonymousVote.call_getter('get_results') == {0:2}
    print('Ok')
    
if __name__ == '__main__':
    # verbose: toggle to print additional execution info
    ts4.init('.')

    test()

