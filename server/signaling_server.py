import asyncio
import json
import websockets

setConnectedSockets = set()
listOffers = []

async def handler(websocket):
    # Register the new client
    setConnectedSockets.add(websocket)
    
    print("Client connected")
    try:
        async for message in websocket:
            data = json.loads(message)
            print(f"Received message: {data}")

            # Handle the offer based on the tag
            if data['type'] == 'newOffer':
                print("Handling unique offer")
                listOffers.append({"offererUserName" : data["offererUserName"],
                                   "sdp" : data["sdp"],
                                   "offerIceCandidates": [],
                                   "answererUserName": None,
                                   "answer": None,
                                   "answererIceCandidates": []
                                   })
                # Send the new offer to all connected clients except the sender
                for client in setConnectedSockets:
                    if client != websocket:
                        print("Sending offer to client")
                        await client.send(json.dumps({
                            "type": "newOfferAwaiting",
                            "offererUserName": data["offererUserName"],
                            "sdp": data["sdp"]
                        }))
            elif data['type'] == 'newAnswer':
                print("Handling unique answer")

            # Broadcast the message to all connected clients except the sender
            for client in setConnectedSockets:
                if client != websocket:
                    await client.send(message)
    except websockets.ConnectionClosed:
        print("Client disconnected")
    finally:
        # Unregister the client
        setConnectedSockets.remove(websocket)

async def main():
    async with websockets.serve(handler, "localhost", 8181):
        print("Signaling server started on ws://localhost:8181")
        await asyncio.Future()  # Run forever

if __name__ == "__main__":
    asyncio.run(main())