import unittest

from server import ExclusiveThreadingHTTPServer, Handler


class ServerTest(unittest.TestCase):
    def test_second_server_cannot_share_the_same_port(self):
        first = ExclusiveThreadingHTTPServer(("127.0.0.1", 0), Handler)
        try:
            port = first.server_address[1]
            with self.assertRaises(OSError):
                ExclusiveThreadingHTTPServer(("127.0.0.1", port), Handler)
        finally:
            first.server_close()


if __name__ == "__main__":
    unittest.main()
