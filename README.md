# p2p-Mesh-Network (v0.1.0)

A localized, decentralized peer-to-peer file transfer system. It streams data directly between devices on the same network using a high-performance Go networking engine and a clean Flutter mobile client.

---

> Note: This project is completely serverless. It relies entirely on local network protocols to discover peers and transfer data safely.

---

## Architecture & Layout

This repository is organized as a unified monorepo:

*   `backend/` (Go) — Core networking engine. Handles local peer discovery, raw TCP socket pipelines, and synchronized file streaming.
*   `frontend/` (Flutter) — Mobile user interface built to manage active transfers smoothly.
*   `cli-prototype/` (Go) — The original command-line prototype used to test the initial protocol logic.

---

## Features & Current State

*   **mDNS Peer Discovery** — Devices automatically broadcast and detect available local nodes without any central registry.
*   **TCP Transport Layer** — Direct node-to-node socket streaming with buffered file handling for stable, fast throughput.
*   **Transfer Synchronization** — Real-time progress tracking percentages are perfectly synchronized between both terminals.

---

## Future Roadmap

*   **v0.2.0 Milestone** — Implementation of an ad-hoc, multi-hop mesh routing protocol to bounce files across indirect nodes.
