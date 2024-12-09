---
title: "Working with Packettracer"
date: 2024-12-09T16:17:28+01:00
tags: ["tutorial", "it-concepts", "guide", "networking"]
author: "hxuu"
showToc: true
TocOpen: true
draft: false
hidemeta: false
comments: true
description: "An in-depth guide on Packettracer"
summary: "Learn about Packettracer in this detailed article."
canonicalURL: ""
disableHLJS: false
disableShare: false
hideSummary: false
ShowReadingTime: true
ShowBreadCrumbs: true
ShowPostNavLinks: true
ShowRssButtonInSectionTermList: true
UseHugoToc: true
cover:
    image: "/images/default-cover.jpg"
    alt: "IT Guide Cover Image"
    caption: "Detailed guide on IT concepts"
    relative: false
    hidden: false
editPost:
    URL: "https://github.com/hxuu/content"
    Text: "Suggest Changes"
    appendFilePath: true
---

## What is Cisco Packet Tracer?

Cisco Packet Tracer is a comprehensive networking simulation software tool for teaching and learning how to create network topologies and imitate modern computer networks.

## Definitions needed to understand what follows

### What is a Swtich?

a switch is most often used to connect individual computers, as shown here:

![a switch](/blog/images/2024-12-09-16-25-57.png)

### What is a Router?

A router directs data between networks, connecting devices and enabling communication by choosing optimal paths for data transmission.


![a router](/blog/images/2024-12-09-16-28-27.png)

### What is a Multi-Layer-Switch

A Multi-Layer Switch combines Layer 2 (switching) and Layer 3 (routing) functions, enabling faster routing within VLANs and between networks.

![Multi-Layer-Switch](/blog/images/2024-12-09-16-30-07.png)

> Note that understanding this basic explanation about each equipment seen here,
as well as the notion of addressing, that is, each equipment is addressable (mac or ip),
will help make the creation and configuration of network topologies easier to understand.

## Key Concepts Viewed

### 1. VLANs

VLANS are best explained by the the following example

Say there is a company building which contains many departments: Finance, Research...etc.

It would make sense that the research department will often NOT want to share information
with its neighboring Finance department. In a normal setting, the separation has
to be physical, but with the help of virtual LANs, the separation can be logical.

VLANs are based on specially-designed VLAN-aware switches, although they may also have
some hubs on the periphery, as in Fig. 4-48. To set up a VLAN-based network, the network
administrator decides how many VLANs there will be, which computers will be on which VLAN,
and what the VLANs will be called.

#### `EXAMPLE`

Achieve the following network topology using cisco packettracer.

![topology-vlan](/blog/images/2024-12-09-16-39-10.png)

1. First, copy paste the topology (no commands, use icons).

![initial-config](/blog/images/2024-12-09-16-48-52.png)

2. Create the VLANs and assign descriptive names to them.

```bash
Switch(config)#vlan 10
Switch(config-vlan)#name blue
Switch(config-vlan)#exit
Switch(config)#vlan 20
Switch(config-vlan)#name green
Switch(config-vlan)#exit
```

> To see if you are correct, type `show vlan`

3. Configure trunk ports (between switches) to carry VLAN tags for inter-switch communication and access ports (between switches and end devices) to assign devices to their respective VLANs correctly.

```bash
# for trunk interfaces
Switch(config)#interface fastEthernet 0/1
Switch(config-if)#switchport mode trunk
Switch(config-if)#switchport trunk allowed vlan 10,20
Switch(config-if)#exit

# for access interfaces
Switch(config)#interface fastEthernet 0/2
Switch(config-if)#switchport mode access
Switch(config-if)#switchport access vlan 10
Switch(config-if)#exit
```

> To see if you are correct, type `show interfaces trunk` or `show vlan brief`

4. Assign IP Addresses to the end-devices (use GUI, no CLI).

5. Test connectivity using the ping command (It should work).

The document covers more than what was discussed here. It covers:

> 1. **Native VLAN**: Configures untagged traffic on trunk ports.
> 2. **VLAN Management**: Assigns an IP address to a VLAN for remote management.
> 3. **Password Configuration**: Secures access to the switch via console and VTY.
> 4. **Saving/Deleting Configurations**: Saves or resets the switch configuration.
> 5. **VLAN Deletion**: Removes a VLAN from the switch.
> 6. **VLAN Creation and Naming**: Creates and names VLANs.
> 7. **Configuration Verification**: Verifies the switch’s configuration status.


### 2. VLANs Using a Multi Layer Switch

![svi-topology](/blog/images/2024-12-09-18-05-00.png)

The goal is for one end-device in one vlan to communicate to another end-device
in another. We keep the same configuration for the three switches and their interfaces,
and we configure the layer 3 switch as follows:

1. Create the VLANs (as shown previously)

2. Switch ports to mode trunk and allow vlan 10 and 20.

```bash
Switch(config)#interface range fastEthernet 0/1 - 3
Switch(config-if)#switchport trunk encapsulation dot1q
Switch(config-if)#switchport mode trunk
Switch(config-if)#switchport trunk allowed vlan 10,20
Switch(config-if)#exit
```

3. Create VLAN interfaces inside the SVI and assign IP addresses to them.

```bash
Switch(config)#interface vlan 10
Switch(config)#ip address 192.168.10.10 255.255.255.0
Switch(config)#exit
Switch(config)#interface vlan 10
Switch(config)#ip address 192.168.10.10 255.255.255.0
```

> The multi layer switch will use the network address of the assigned IP to consult
its routing table to route the packet to its destination.

4. Enable routing on the Layer 3 Switch to route inter-vlan traffic.

```bash
Switch(config)#ip routing
```

5. Link end-devices with the switch by modify their default gateway to match the address
assigned to the VLAN interface of the SVI (use gui).

6. Test connectivity between two devices from diffrent VLANs.

### 3. Routing

The network layer is concerned with getting packets from the source all the way to the
destination. Getting to the destination may require making many hops at intermediate routers
along the way, thus requiring a routing procotol.

We can either define our routes statically (1st routing TP), or dynamically (2nd TP),
but overall, our job or the routing protocol's is the same: Provide the information
necessary to move the packet from one router to another to ultimately reach the destination.

> you need to add NIM-2T (Network Interface Module - 2T) or a similar serial interface module to your routers in Cisco Packet Tracer to use serial connections.

Make sure you copy this topology before proceeding.

![routing-topology](/blog/images/2024-12-09-19-11-18.png)

#### `Static Routing`

Static routing involves manually configuring routes on each router to define explicit paths for network traffic.

1. Assign IP Addresses to Interfaces:

```bash
# for each router, change the interface-id and addr with those correct
# these are for direct connection.
Router(config)#interface gigabitEthernet 0/0/0
Router(config-if)#ip address 192.168.3.1 255.255.255.0
Router(config-if)#no shutdown
Router(config-if)#exit
```

2. Add Static Routes:


```bash
# Syntax: ip route <network-address> <subnet-mask> <next-hop-ip | exit-interface>
Router(config)#ip route 192.168.4.0 255.255.255.0 192.168.1.2

# static routing (optional)
Router(config)#ip route 0.0.0.0 0.0.0.0 192.168.1.2
```

> To verify routing use the command `show ip route`

3. Test connectivity using the ping command (You have to assign each device an IP addr + default gateway).

> Note that the default static route has be unique accross your topology or problems
will occur.

#### `Dynamic Routing`

We'll use the RIP protocol which shares the information of routing accross gateways
participating in the routing mechanism through a multicast address.

To setup this dynamic routing, remove the static routing (keep only those directly
connected):

```bash
#no ip route ...
```

Then follow these steps:

1. Activate the RIP Process, set the RIP version and disable Auto-Summary for each
router participating in the protocol.

```bash
Router(config)#router rip
Router(config-router)#version 2
Router(config-router)#no auto-summary
```

2. Declare networks directly connected to the router.

```bash
Router(config-router)#network 192.168.1.0
Router(config-router)#network 192.168.3.0
```

3. Advertise a Default Route

```bash
# in the router that the default route is defined at
Router(config-router)#default-information originate
```

4. Test connectivity using the ping command (give router a bit of time to share the
routing information between each other)

### 4. Bonus (Inter VLAN Using a Router)



Summarize the key points and takeaways of the article.
## Summary

Summarize the key points and takeaways of the article.

