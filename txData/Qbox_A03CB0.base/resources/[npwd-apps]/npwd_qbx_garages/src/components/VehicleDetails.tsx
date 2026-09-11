import React from 'react';
import { GarageItem } from '../types/garage';
import {
  Avatar,
  Button,
  List,
  ListItem,
  ListItemIcon,
  ListItemText,
  Typography,
  ListItemAvatar,
} from '@mui/material';
import LinearProgress, { LinearProgressProps } from '@mui/material/LinearProgress';
import Box from '@mui/material/Box';
import DirectionsCarIcon from '@mui/icons-material/DirectionsCar';
import LocationOnIcon from '@mui/icons-material/LocationOn';
import LocalGasStationIcon from '@mui/icons-material/LocalGasStation';
import MyLocationIcon from '@mui/icons-material/MyLocation';
import BuildIcon from '@mui/icons-material/Build';
import { ServerPromiseResp } from '../types/common';
import fetchNui from '../utils/fetchNui';

type CustomColor = 'error' | 'warning' | 'success';

function LinearProgressWithLabel(props: LinearProgressProps & { value: number }) {
  let color: CustomColor = 'error';

  if (props.value > 25 && props.value <= 75) {
    color = 'warning';
  } else if (props.value > 75 && props.value <= 100) {
    color = 'success';
  }

  return (
    <Box sx={{ display: 'flex', alignItems: 'center' }}>
      <Box sx={{ width: '100%', mr: 1 }}>
        <LinearProgress color={color} variant="determinate" {...props} />
      </Box>
      <Box sx={{ minWidth: 35 }}>
        <Typography variant="body2" color="text.secondary">{`${Math.round(
          props.value,
        )}%`}</Typography>
      </Box>
    </Box>
  );
}

export function LinearWithValueLabel() {
  const [progress, setProgress] = React.useState(10);

  React.useEffect(() => {
    const timer = setInterval(() => {
      setProgress((prevProgress) => (prevProgress >= 100 ? 10 : prevProgress + 10));
    }, 800);
    return () => {
      clearInterval(timer);
    };
  }, []);

  return (
    <Box sx={{ width: '100%' }}>
      <LinearProgressWithLabel value={progress} />
    </Box>
  );
}

const VehicleDetails = ({ veh }: { veh: GarageItem }) => {

  const handleTrackVehicle = (plate: string) => {
    fetchNui<ServerPromiseResp>('npwd:qbx_garage:requestWaypoint', { plate }).then((res) => {
      console.log(res);
    });
  };

  return (
    <>
      <List sx={{ width: '100%' }}>
        <ListItem disablePadding sx={{ mb: '8px' }}>
          <ListItemIcon sx={{ ml: '5px', minWidth: '20px' }}>
            <ListItemAvatar>
              <Avatar>
              <LocationOnIcon />
              </Avatar>
              </ListItemAvatar>
          </ListItemIcon>
          <ListItemText primary='Location' secondary={veh.garage} />
        </ListItem>

        <ListItem disablePadding sx={{ mb: '8px' }}>
          <ListItemIcon sx={{ ml: '5px', minWidth: '20px' }}>
            <ListItemAvatar>
              <Avatar>
              <BuildIcon />
              </Avatar>
              </ListItemAvatar>
          </ListItemIcon>
          <ListItemText primary='Engine' secondary={<LinearProgressWithLabel value={Math.ceil(veh.engine / 10)} />} />
        </ListItem>
        <ListItem disablePadding sx={{ mb: '8px' }}>
          <ListItemIcon sx={{ ml: '5px', minWidth: '20px' }}>
            <ListItemAvatar>
              <Avatar>
              <LocalGasStationIcon />
              </Avatar>
              </ListItemAvatar>
          </ListItemIcon>
          <ListItemText primary='Fuel' secondary={<LinearProgressWithLabel value={Math.ceil(veh.fuel)} />} />
        </ListItem>
        <ListItem disablePadding sx={{ mb: '8px' }}>
          <ListItemIcon sx={{ ml: '5px', minWidth: '20px' }}>
            <ListItemAvatar>
              <Avatar>
              <DirectionsCarIcon />
              </Avatar>
              </ListItemAvatar>
          </ListItemIcon>
          <ListItemText primary='Body' secondary={<LinearProgressWithLabel value={Math.ceil(veh.body / 10)} />} />
        </ListItem>
      </List>

      <Button
        color='info'
        variant='outlined'
        disabled={veh.state !== 'out'}
        onClick={() => handleTrackVehicle(veh.plate)}
        startIcon={<MyLocationIcon />}
      >
        Locate
      </Button>
    </>
  );
};

export default VehicleDetails;