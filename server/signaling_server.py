import asyncio
import json
import websockets

connected_clients = set()

async def handler(websocket, path):
    # Register the new client
    connected_clients.add(websocket)
    print("Client connected")
    try:
        async for message in websocket:
            data = json.loads(message)
            print(f"Received message: {data}")

            # Handle the offer based on the tag
            if data['type'] == 'newOffer' and data.get('tag') == 'unique_offer_tag':
                print("Handling unique offer")

            # Broadcast the message to all connected clients except the sender
            for client in connected_clients:
                if client != websocket:
                    await client.send(message)
    except websockets.ConnectionClosed:
        print("Client disconnected")
    finally:
        # Unregister the client
        connected_clients.remove(websocket)

async def main():
    async with websockets.serve(handler, "localhost", 8181):
        print("Signaling server started on ws://localhost:8181")
        await asyncio.Future()  # Run forever

if __name__ == "__main__":
    asyncio.run(main())