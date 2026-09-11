import {
  Box,
  ListItem,
  List,
  ListSubheader,
  Collapse,
  Accordion,
  AccordionSummary,
  Typography,
  AccordionDetails,
  Stack,
} from '@mui/material';
import { green, grey, orange, red } from '@mui/material/colors';
import React, { useState } from 'react';
import { GarageItem } from '../types/garage';
import FlightIcon from '@mui/icons-material/Flight';
import PedalBikeIcon from '@mui/icons-material/PedalBike';
import DirectionsCarIcon from '@mui/icons-material/DirectionsCar';
import DirectionsBoatIcon from '@mui/icons-material/DirectionsBoat';
import VehicleDetails from './VehicleDetails';

interface VehicleListProps {
  isDarkMode: boolean;
  vehicles: Map<string, GarageItem[]>;
}

export const VehicleList: React.FC<VehicleListProps> = ({ vehicles, isDarkMode }) => {
  const [collapseId, setCollapseId] = useState<string | null>(null);
  const typeIcon = {
    car: {
      icon: <DirectionsCarIcon sx={{ fontSize: 35 }} />,
      status: {
        out: orange[500],
        garaged: green[500],
        impounded: red[500],
        seized: red[500],
        unknown: grey[500],
      },
    },
    aircraft: {
      icon: <FlightIcon sx={{ fontSize: 35 }} />,
      status: {
        out: orange[500],
        garaged: green[500],
        impounded: red[500],
        seized: red[500],
        unknown: grey[500],
      },
    },
    boat: {
      icon: <DirectionsBoatIcon sx={{ fontSize: 35 }} />,
      status: {
        out: orange[500],
        garaged: green[500],
        impounded: red[500],
        seized: red[500],
        unknown: grey[500],
      },
    },
    bike: {
      icon: <PedalBikeIcon sx={{ fontSize: 35 }} />,
      status: {
        out: orange[500],
        garaged: green[500],
        impounded: red[500],
        seized: red[500],
        unknown: grey[500],
      },
    },
  };

  const expandItem = (id: string) => {
    setCollapseId(id !== collapseId ? id : null);
  };

  return (
    <Box>
      {Array.from(vehicles.keys()).map(key => (
        <List
          subheader={
            <ListSubheader
              sx={{
                cursor: 'pointer',
                position: 'static',
                boxShadow:
                  '1px 0px 1px -1px rgba(0,0,0,0.2), 0px 1px 1px 0px rgba(0,0,0,0.14), 0px 1px 3px 0px rgba(0,0,0,0.12)',
                backgroundColor: isDarkMode ? 'rgb(38 38 38 / 1)' : '#fff',
              }}
              onClick={() => expandItem(key)}
            >
              {key.toUpperCase()}
            </ListSubheader>
          }
        >
          <Collapse in={collapseId === key}>
            {vehicles.get(key)?.map(veh => {
              return (
                <ListItem disablePadding sx={{ marginTop: '10px' }}>
                  <Accordion
                    sx={{
                      width: '100%',
                      borderBottom: '4px solid',
                      borderBottomColor: typeIcon[veh.type].status[veh.state],
                      backgroundColor: isDarkMode ? 'rgb(38 38 38 / 1)' : '#fff',
                      backgroundImage: 'none'
                    }}
                  >
                    <AccordionSummary>
                      <Box
                        sx={{
                          display: 'flex',
                          justifyContent: 'space-between',
                          width: '100%',
                          alignItems: 'center',
                        }}
                      >
                        <Box sx={{ display: 'flex', gap: 3, alignItems: 'center' }}>
                          {typeIcon[veh.type].icon}
                          <Stack spacing={0}>
                            <Typography sx={{ fontSize: 15 }}>
                              {veh.brand + ' ' + veh.vehicle}
                            </Typography>
                            <Typography sx={{ fontSize: 12, color: isDarkMode? 'rgba(255, 255, 255, 0.7)' : 'rgba(0, 0, 0, 0.87)' }}>Plate: {veh.plate}</Typography>
                          </Stack>
                        </Box>
                        <Stack sx={{padding: '5px', alignItems: 'end'}} spacing={0}>
                            <Typography sx={{ fontSize: 15 }}>
                              State
                            </Typography>
                            <Typography sx={{ fontSize: 12, color: isDarkMode? 'rgba(255, 255, 255, 0.7)' : 'rgba(0, 0, 0, 0.87)', textTransform: 'capitalize' }}>{veh.state}</Typography>
                          </Stack>
                      </Box>
                    </AccordionSummary>
                    <AccordionDetails
                      sx={{
                        display: 'flex',
                        justifyContent: 'center',
                        alignItems: 'center',
                        flexDirection: 'column',
                      }}
                    >
                      <VehicleDetails veh={veh} />
                    </AccordionDetails>
                  </Accordion>
                </ListItem>
              );
            })}
          </Collapse>
        </List>
      ))}
    </Box>
  );
};
