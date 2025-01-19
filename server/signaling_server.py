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
            print(f"Received message: {data}")

            if data['type'] == 'auth':
                print("Handling auth")
                dictConnectedSockets[data['userName']] = websocket
                if(len(listOffers) > 0):
                    print("Sending offers to new client")
                    for offer in listOffers:
                        if offer["offererUserName"] != data['userName']:
                            await websocket.send(json.dumps({
                                "type": "newOfferAwaiting",
                                "offererUserName": offer["offererUserName"],
                                "sdp": offer["sdp"],
                                "offerIceCandidates": offer["offerIceCandidates"],
                                "answererUserName": None,
                                "answer": None,
                                "answererIceCandidates": []
                            }))


            # Handle the offer based on the tag
            elif data['type'] == 'newOffer':
                print("Handling unique offer")
                listOffers.append({"offererUserName" : data["offererUserName"],
                                   "sdp" : data["sdp"],
                                   "offerIceCandidates": [],
                                   "answererUserName": None,
                                   "answer": None,
                                   "answererIceCandidates": []
                                   })
                # Send the new offer to all connected clients except the sender
                for clientName in dictConnectedSockets.keys():
                    if dictConnectedSockets[clientName] != websocket:
                        print("Sending offer to client")
                        await dictConnectedSockets[clientName].send(json.dumps({
                            "type": "newOfferAwaiting",
                            "offererUserName": data["offererUserName"],
                            "sdp": data["sdp"],
                            "offerIceCandidates": [],
                            "answererUserName": None,
                            "answer": None,
                            "answererIceCandidates": []
                        }))
            elif data['type'] == 'newAnswer':
                print("Handling unique answer")
                nCounter = 0
                for offer in listOffers:
                    if data["toWhome"] == offer["offererUserName"]:
                        strOffererName = data["toWhome"]
                        listOffers[nCounter]["answererUserName"] = data["answererUserName"]
                        listOffers[nCounter]["answer"] = data["answerSDP"]
                        print("Found offer")
                        dictConnectedSockets[offer["offererUserName"]].send
                    nCounter += 1

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