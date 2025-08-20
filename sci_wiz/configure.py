#!/usr/bin/env python
"""
Created on 2024-01-24 15:30:22
Module desc: configuration module with utility function to do setup chores.
@author: m.sikarwar
"""
from sci_wiz.interface_command import ICommand
from pathlib import Path
import configparser
import logging
import time
from os.path import join

logger = logging.getLogger(__name__)


class Configure(ICommand):
    def __init__(self) -> None:
        pass

    def write_user_config(self, filePath: str = None):
        """
        Write user configuration file.
        """
        if filePath is None:
            filePath = Path().cwd().joinpath("user_input.ini")
        else:
            filePath = Path(filePath)
        configTmpl = f"""
        [USER_INPUT]
        project_name = G123_{time.strftime("%y%m", time.localtime())}_uniqueName  # project name for your run
        profile = hpc    # 'vm' if running on VM, 'hpc' if running on HPC.
        reads= /data/OMICS/project_name/*/*_{{R1,R2}}_001.fastq.gz # absolute path
        output_dir= /project_name/Data/
        index= STAR_75bp_or_150bp
        annotation= Org.OrgCode.110.gtf
        reference= Org.OrgCode.110.fa
        annotation_bed= Org.OrgCode.110.bed
        fastqscreen_db_dir = /path/to/FastQ_Screen_Genomes # Path to a folder that contains 'fastq_screen.conf' and the Bowtie2 indices it references.
        batch_info= false   # batch_info True will require run1, run2, batch_destination, input_reads will be ignored.
        run1=
        run2=
        batch_destination=
        [TRIMMING]
        trim_front_read_01 = 1 # will trim the front bases from read 1
        trim_front_read_02 = 1 # will trim front bases from read 2
        trim_tail_read_01 = 0 # will trim tail bases from read 1
        trim_tail_read_02 = 0 # will trim tail bases from read 2
        """
        userConfig = configparser.ConfigParser()
        userConfig.read_string(configTmpl)
        with open(filePath, "w") as configFile:
            userConfig.write(configFile)
        logger.info(f"User configuration file written to: {filePath}")

    def execute(self):
        """
        Execute configuration.
        """
        self.write_user_config()
        pass

    @staticmethod
    def load_config(config: Path | str = "user_input.ini"):
        configFile = configparser.ConfigParser(inline_comment_prefixes="#")
        configFile.read(config)
        inputJson = dict()
        sections = configFile.sections()
        for section in sections:  # avoid sections in input json
            for key, val in configFile[section].items():
                inputJson[key] = val
        # TODO: find alternate for the hard coded part
        inputJson["batch_info"] = configFile["USER_INPUT"].getboolean(
            "batch_info"
        )  # handle boolean input
        inputJson["output_dir"] = join(inputJson["output_dir"], inputJson["project_name"])
        return inputJson
