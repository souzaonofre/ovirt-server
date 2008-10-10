#!/usr/bin/python

# This script is temporary!  It's just a demo to show how the qpid
# stuff works.  This prints out a hierarchy of nodes/domains/pools/volumes
# every five seconds.

from qpid.qmfconsole import Session
import time

s = Session()
b = s.addBroker()

while True:
    nodes = s.getObjects(cls="node")
    for node in nodes:
        print 'node:', node.hostname
        for prop in node.properties:
            print "  property:", prop
        # Find any domains that on the current node.
        domains = s.getObjects(cls="domain", node=node.objectId)
        for domain in domains:
            print '  domain:', domain.name
            for prop in domain.properties:
                print "    property:", prop

        pools = s.getObjects(cls="pool", node=node.objectId)
        for pool in pools:
            print '  pool:', pool.name
            for prop in pool.properties:
                print "    property:", prop

            # Find volumes that are part of the pool.
            volumes = s.getObjects(cls="volume", pool=pool.objectId)
            for volume in volumes:
                print '    volume:', volume.name
                for prop in volume.properties:
                    print "      property:", prop

    time.sleep(5)

    print '----------------------------'

