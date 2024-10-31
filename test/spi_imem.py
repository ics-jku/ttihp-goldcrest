from cocotbext.spi import SpiMaster, SpiBus, SpiConfig, SpiSlaveBase
import struct

class SpiIMem(SpiSlaveBase):
    def __init__(self, bus):
        self._config = SpiConfig(
            word_width = 32,
            cpha = True,
            msb_first  = False
        )
        self.content = 0
        super().__init__(bus)

        self.mem = [
            0x93000000,
            0x93801000,
            0x6ff0dfff,
        ]

    async def get_content(self):
        await self.idle.wait()
        return self.content

    async def _transaction(self, frame_start, frame_end):
        await frame_start
        self.idle.clear()

        cmd = await self._shift(8)
        adr = await self._shift(24)
        self.content = self.mem[adr]
        await self._shift(32, tx_word=self.content)

        await frame_end
