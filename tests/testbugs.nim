#                Chronos Test Suite
#            (c) Copyright 2018-Present
#         Status Research & Development GmbH
#
#              Licensed under either of
#  Apache License, version 2.0, (LICENSE-APACHEv2)
#              MIT license (LICENSE-MIT)
import unittest
import ../chronos

when defined(nimHasUsed): {.used.}

suite "Asynchronous issues test suite":
  const HELLO_PORT = 45679
  const TEST_MSG = "testmsg"
  const MSG_LEN = TEST_MSG.len()
  const TestsCount = 500

  type
    CustomData = ref object
      test: string

  proc udp4DataAvailable(transp: DatagramTransport,
                       remote: TransportAddress): Future[void] {.async, gcsafe.} =
    var udata = getUserData[CustomData](transp)
    var expect = TEST_MSG
    var data: seq[byte]
    var datalen: int
    transp.peekMessage(data, datalen)
    if udata.test == "CHECK" and datalen == MSG_LEN and
       equalMem(addr data[0], addr expect[0], datalen):
      udata.test = "OK"
    transp.close()

  proc issue6(): Future[bool] {.async.} =
    var myself = initTAddress("127.0.0.1:" & $HELLO_PORT)
    var data = CustomData()
    data.test = "CHECK"
    var dsock4 = newDatagramTransport(udp4DataAvailable, udata = data,
                                      local = myself)
    await dsock4.sendTo(myself, TEST_MSG, MSG_LEN)
    await dsock4.join()
    if data.test == "OK":
      result = true

  proc testWait(): Future[bool] {.async.} =
    for i in 0 ..< TestsCount:
      try:
        await wait(sleepAsync(4.milliseconds), 4.milliseconds)
      except AsyncTimeoutError:
        discard
    result = true

  proc testWithTimeout(): Future[bool] {.async.} =
    for i in 0 ..< TestsCount:
      discard await withTimeout(sleepAsync(4.milliseconds), 4.milliseconds)
    result = true

  test "Issue #6":
    check waitFor(issue6()) == true

  test "Callback-race double completion [wait()] test":
    check waitFor(testWait()) == true

  test "Callback-race double completion [withTimeout()] test":
    check waitFor(testWithTimeout()) == true
