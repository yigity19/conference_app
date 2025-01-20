import asyncio
import json
import websockets

dictConnectedSockets = dict()
listOffers = []

async def handler(websocket):
    # Register the new client
    
    print("Client connected")
    try:
        async for message in websocket:
            data = json.loads(message)
            if data['type'] == 'auth':
                print("Handling auth for user " + data['userName'])
                dictConnectedSockets[data['userName']] = websocket
                if(len(listOffers) > 0):
                    for offer in listOffers:
                        if offer["offererUserName"] != data['userName']:
                            print("Sending offers to new client" + offer['offererUserName'])
                            await websocket.send(json.dumps({
                                "type": "newOfferAwaiting",
                                "offererUserName": offer["offererUserName"],
                                "offerSDP": offer["offerSDP"],
                                "offerType": offer["offerType"],
                                "offerIceCandidates": offer["offerIceCandidates"],
                                "answererUserName": None,
                                "answerType": None,
                                "answerSDP": None,
                                "answererIceCandidates": []
                            }))


            # Handle the offer based on the tag
            elif data['type'] == 'newOffer':
                print("Handling unique offer")
                listOffers.append({"offererUserName" : data["offererUserName"],
                                   "offerSDP" : data["offerSDP"],
                                   "offerType" : data["offerType"],
                                   "offerIceCandidates": [],
                                   "answererUserName": None,
                                   "answerType": None,
                                   "answerSDP": None,
                                   "answererIceCandidates": []
                                   })
                # Send the new offer to all connected clients except the sender
                for clientName in dictConnectedSockets.keys():
                    if dictConnectedSockets[clientName] != websocket:
                        print("Sending offer to client")
                        await dictConnectedSockets[clientName].send(json.dumps({
                            "type": "newOfferAwaiting",
                            "offererUserName": data["offererUserName"],
                            "offerSDP": data["offerSDP"],
                            "offerType": data["offerType"],
                            "offerIceCandidates": [],
                            "answererUserName": None,
                            "answer": None,
                            "answererIceCandidates": []
                        }))

            elif data['type'] == 'newAnswer':
                print("Handling answer of " + data["answererUserName"])
                nCounter = 0
                for offer in listOffers:
                    if data["toWhome"] == offer["offererUserName"]:
                        # toSend = dict()
                        # toSend["type"] = "answerResponse"
                        # toSend["answererUserName"] = data["answererUserName"]
                        # toSend["answerSDP"] = data["answerSDP"]
                        # toSend["answerType"] = data["answerType"]
                        # toSend["offererUserName"] = data["toWhome"]
                        listOffers[nCounter]["type"] = "answerResponse"
                        listOffers[nCounter]["answererUserName"] = data["answererUserName"]
                        listOffers[nCounter]["answerSDP"] = data["answerSDP"]
                        listOffers[nCounter]["answerType"] = data["answerType"]
                        print("Found offer")
                        await dictConnectedSockets[offer["offererUserName"]].send(json.dumps(listOffers[nCounter]))
                    nCounter += 1

            elif data['type'] == 'sendIceCandidateToSignalingServer':
                if data["isOfferer"]:
                    for offer in listOffers:
                        if data["iceUserName"] == offer["offererUserName"]:
                            print("Found offerer for adding ice candidate")
                            offer["offerIceCandidates"].append({"iceUserName": data["iceUserName"],
                                                                "isOfferer": data["isOfferer"],
                                                                "icecandidate": data["icecandidate"],
                                                                'sdpMid': data['sdpMid'],
                                                                'sdpMLineIndex': data['sdpMLineIndex']
                                                                })
                            if(offer["answererUserName"] != None):
                                print("Sending ice candidate to answerer " + offer["answererUserName"])
                                await dictConnectedSockets[offer["answererUserName"]].send(json.dumps({
                                    "type": "receivedIceCandidateFromServer",
                                    "iceUserName": data["iceUserName"],
                                    "isOfferer": data["isOfferer"],
                                    "icecandidate": data["icecandidate"],
                                    'sdpMid': data['sdpMid'],
                                    'sdpMLineIndex': data['sdpMLineIndex']
                                }))
                            break
                else:                   
                    for offer in listOffers:
                        if data["iceUserName"] == offer["answererUserName"]:
                            print("Found answerer for adding ice candidate")
                            offer["answererIceCandidates"].append({"iceUserName": data["iceUserName"],
                                                                "isOfferer": data["isOfferer"],
                                                                "icecandidate": data["icecandidate"],
                                                                'sdpMid': data['sdpMid'],
                                                                'sdpMLineIndex': data['sdpMLineIndex']
                                                                })
                            if(offer["offererUserName"] != None):
                                print("Sending ice candidate to offerer " + offer["offererUserName"])
                                await dictConnectedSockets[offer["offererUserName"]].send(json.dumps({
                                    "type": "receivedIceCandidateFromServer",
                                    "iceUserName": data["iceUserName"],
                                    "isOfferer": data["isOfferer"],
                                    "icecandidate": data["icecandidate"],
                                    'sdpMid': data['sdpMid'],
                                    'sdpMLineIndex': data['sdpMLineIndex']
                                }))
                            break
            elif data['type'] == 'newAnswerReqeustIceCandidates':
                for offer in listOffers:
                    if(data["answererUserName"] == offer["answererUserName"]):
                        print("Sending ice candidate to answerer " + offer["answererUserName"] + " from offerer " + offer["offererUserName"])
                        for iceCandidate in offer["offerIceCandidates"]:
                            await dictConnectedSockets[offer["answererUserName"]].send(json.dumps({
                                "type": "responseToAnswererIceCandidatesRequest",
                                "iceUserName": iceCandidate["iceUserName"],
                                "isOfferer": iceCandidate["isOfferer"],
                                "icecandidate": iceCandidate["icecandidate"],
                                'sdpMid': iceCandidate['sdpMid'],
                                'sdpMLineIndex': iceCandidate['sdpMLineIndex']
                            }))
                        break


            # Broadcast the message to all connected clients except the sender
            # for clientName in dictConnectedSockets.keys():
            #     if dictConnectedSockets[clientName] != websocket:
            #         await dictConnectedSockets[clientName].send(message)
    except websockets.ConnectionClosed:
        print("Client disconnected")
    finally:
        # Unregister the client
        for key in dictConnectedSockets.keys():
            if dictConnectedSockets[key] == websocket:
                dictConnectedSockets.pop(key)
                break

async def main():
    async with websockets.serve(handler, "localhost", 8181):
        print("Signaling server started on ws://localhost:8181")
        await asyncio.Future()  # Run forever

if __name__ == "__main__":
    asyncio.run(main())